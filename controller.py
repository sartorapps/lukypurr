import logging
import threading
import time
import os
import random
import tempfile
from PySide6.QtCore import QObject, Slot, Signal, Property, QTimer, QUrl
from PySide6.QtWidgets import QFileDialog

log = logging.getLogger("lukypurr.controller")
from services.music_service import MusicService
from services.stream_service import StreamService
from services.audio_player import AudioPlayer
from services.favorites_service import FavoritesService
from services.tray_service import TrayService
from services.spectral_service import SpectralService
from services.settings_service import SettingsService
from services.theme_service import ThemeService
from services.download_service import DownloadService


def _image_ext(blob: bytes) -> str:
    """Extensao a partir da assinatura da imagem (jpg/png/webp)."""
    if blob[:3] == b"\xff\xd8\xff":
        return ".jpg"
    if blob[:8] == b"\x89PNG\r\n\x1a\n":
        return ".png"
    if blob[:4] == b"RIFF" and blob[8:12] == b"WEBP":
        return ".webp"
    return ".jpg"


def _extract_apic(data: bytes):
    """Extrai o primeiro frame APIC (capa) de um arquivo MP3 com tag ID3v2.

    Nao depende de biblioteca externa: faz o parse manual do cabecalho ID3
    e das frames, suportando ID3v2.2/2.3/2.4. Devolve os bytes da imagem
    (JPEG/PNG/WebP) ou None. Funciona independente do formato em que o
    yt-dlp/ffmpeg embutiu a capa.
    """
    if data[:3] != b"ID3":
        return None
    # cabecalho ID3v2: 'ID3' + ver(2) + flags(1) + size(4 syncsafe)
    if len(data) < 10:
        return None
    major = data[3]
    size = _syncsafe_int(data[6:10])
    if size <= 0 or size + 10 > len(data):
        return None
    pos = 10
    end = 10 + size
    if major == 2:
        apic = b"PIC"
    else:
        apic = b"APIC"
    while pos + 10 < end:
        fid = data[pos:pos + 3] if major == 2 else data[pos:pos + 4]
        if fid not in (b"APIC", b"PIC"):
            # avanca uma frame (cabecalho + corpo)
            if major == 2:
                fsize = int.from_bytes(data[pos + 3:pos + 6], "big")
                pos += 6 + fsize
            else:
                fsize = _id3v2_frame_size(data, pos, major)
                if fsize <= 0:
                    break
                pos += 10 + fsize
            continue
        # achou APIC/PIC
        if major == 2:
            fsize = int.from_bytes(data[pos + 3:pos + 6], "big")
            body = data[pos + 6:pos + 6 + fsize]
        else:
            fsize = _id3v2_frame_size(data, pos, major)
            body = data[pos + 10:pos + 10 + fsize]
        # parser do corpo
        try:
            if major == 2:
                # PIC: <1 byte texto> <3 bytes formato> <desc terminada em \0> <imagem>
                if not body:
                    return None
                encoding = body[0]
                fmt = body[1:4]
                desc_start = 4
            else:
                # APIC: <encoding> <mime terminada em \0> <picture type 1 byte> <desc terminada> <imagem>
                if not body:
                    return None
                encoding = body[0]
                nul = body.find(b"\x00", 1)
                if nul < 0:
                    return None
                mime = body[1:nul]
                ptype = body[nul + 1]
                desc_start = nul + 2
            # descricao termina em \0 (encoding 0/1: latin1/utf8; 2/3: utf16)
            if encoding in (2, 3):
                term = b"\x00\x00"
                d = body.find(term, desc_start)
                img_start = d + 2 if d >= 0 else desc_start
            else:
                n = body.find(b"\x00", desc_start)
                img_start = n + 1 if n >= 0 else desc_start
            img = body[img_start:]
            if img:
                return img
        except Exception:
            return None
    return None


def _syncsafe_int(b: bytes) -> int:
    """Converte 4 bytes sync-safe (7 bits por byte) em int."""
    return (b[0] << 21) | (b[1] << 14) | (b[2] << 7) | b[3]


def _id3v2_frame_size(data: bytes, pos: int, major: int) -> int:
    """Tamanho de uma frame ID3v2.3/2.4 (ou -1 se invalido)."""
    if major == 4:
        return _syncsafe_int(data[pos + 4:pos + 8])
    return int.from_bytes(data[pos + 4:pos + 8], "big")


class Controller(QObject):
    searchResultsChanged = Signal()
    searchErrorChanged = Signal()
    currentTrackChanged = Signal()
    queueChanged = Signal()
    isPlayingChanged = Signal()
    loadingChanged = Signal()
    viewChanged = Signal()
    spectrumChanged = Signal()
    _newQueueReady = Signal(list)
    downloadStatusChanged = Signal()
    offlineTracksChanged = Signal()
    offlineModeChanged = Signal()
    offlineControlsChanged = Signal()

    # Extensoes de audio reproduziveis offline (sem-numeros-magicos)
    OFFLINE_EXTS = (".mp3", ".m4a", ".flac", ".ogg", ".wav")
    # Pasta de cache para capas extraidas dos MP3 (embed nao-padrao)
    _COVER_CACHE_DIR = os.path.join(tempfile.gettempdir(), "lukypurr_covers")

    def __init__(self):
        super().__init__()
        self._search_results = []
        self._search_error = ""
        self._current_track = {}
        self._queue = []
        self._queue_index = -1
        self._is_playing = False
        self._loading = False
        self._user_paused = False
        self._loading_track = False
        self._view = "search"
        self._generating = False
        self._spectrum = []
        self._last_position = 0.0
        self._stuck_count = 0
        self._offline_tracks = []
        self._offline_mode = False
        self._offline_shuffle = False
        self._offline_repeat = False

        self._watchdog = QTimer()
        self._watchdog.setInterval(5000)
        self._watchdog.timeout.connect(self._check_stuck)
        self._watchdog.start()

        self.music_service = MusicService()
        self.stream_service = StreamService()
        self.audio_player = AudioPlayer()
        self.favorites_service = FavoritesService()
        self.tray_service = TrayService()
        self.spectral_service = SpectralService()
        self.settings_service = SettingsService()
        self.theme_service = ThemeService()
        self.download_service = DownloadService()

        self.music_service.searchResults.connect(self._on_search_results)
        self.music_service.searchFailed.connect(self._on_search_failed)
        self.stream_service.streamUrlReady.connect(self._on_stream_ready)
        self.audio_player.stateChanged.connect(self._on_player_state)
        self.audio_player.pcmReady.connect(self.spectral_service.analyze_pcm)
        self.audio_player.volumeChanged.connect(self._on_volume_changed)
        self.favorites_service.favoritesChanged.connect(self._on_favorites_changed)
        self.spectral_service.spectrumReady.connect(self._on_spectrum)
        self.download_service.downloadStatusChanged.connect(self.downloadStatusChanged.emit)
        self._newQueueReady.connect(self._on_new_queue_ready)

        self.tray_service.trayPlay.connect(self.resume)
        self.tray_service.trayPause.connect(self.pause)
        self.tray_service.trayNext.connect(self.next)
        self.tray_service.trayPrev.connect(self.previous)
        self.tray_service.trayClose.connect(self._on_tray_close)

        # Volume salvo na última sessão
        try:
            saved = self.settings_service.volume
            self.audio_player.set_volume(saved)
        except Exception:
            pass

    def setup_tray(self):
        self.tray_service.setup()

    def _on_volume_changed(self, vol: float):
        try:
            self.settings_service.set_volume(vol)
        except Exception:
            pass

    @property
    def player_service(self):
        return self.audio_player

    @Slot(str)
    def search(self, query: str):
        self.music_service.search(query)

    def _on_search_results(self, results):
        self._search_results = results
        self._search_error = ""
        self.searchErrorChanged.emit()
        self.searchResultsChanged.emit()

    def _on_search_failed(self, message: str):
        self._search_results = []
        self._search_error = message
        self.searchErrorChanged.emit()
        self.searchResultsChanged.emit()

    def _on_favorites_changed(self, favorites):
        self.searchResultsChanged.emit()

    def _on_spectrum(self, data):
        self._spectrum = data
        self.spectrumChanged.emit()

    def _check_stuck(self):
        if not self._is_playing:
            self._stuck_count = 0
            return
        if not self._current_track:
            return
        try:
            pos = self.audio_player.position
            dur = self.audio_player.duration
            if pos < 1.0 or dur < 1.0:
                self._stuck_count = 0
                return
            if abs(pos - self._last_position) < 0.1:
                self._stuck_count += 1
                if self._stuck_count >= 6:
                    self._auto_next()
                    self._stuck_count = 0
            else:
                self._stuck_count = 0
            self._last_position = pos
        except Exception:
            pass

    def _on_stream_ready(self, video_id: str, url: str):
        if self._current_track.get("videoId") == video_id and url:
            self.audio_player.play(url)

    def _on_player_state(self, state: str):
        if self._loading_track and state == "stopped":
            return
        if state == "playing":
            self._loading_track = False
            if self._loading:
                self._loading = False
                self.loadingChanged.emit()
        self._is_playing = state == "playing"
        self.isPlayingChanged.emit()
        if state == "stopped" and not self._user_paused:
            QTimer.singleShot(600, self._auto_next)

    @Slot(int)
    def play_track(self, index: int):
        tracks = self._search_results
        if 0 <= index < len(tracks):
            self._queue = [tracks[index]]
            self._queue_index = 0
            self._load_current_track()

    @Slot("QVariant")
    def play_from_list(self, track: dict):
        self._queue = [track]
        self._queue_index = 0
        self._load_current_track()

    @Slot(int)
    def play_from_queue(self, index: int):
        if 0 <= index < len(self._queue):
            self._queue_index = index
            self._load_current_track()

    @Slot("QVariant")
    def add_to_queue(self, track: dict):
        video_id = track.get("videoId", "")
        if not video_id:
            return
        for t in self._queue:
            if t.get("videoId") == video_id:
                return
        self._queue.append(track)
        self.queueChanged.emit()

    @Slot(list)
    def add_tracks_to_queue(self, tracks: list):
        existing = {t.get("videoId") for t in self._queue}
        for track in tracks:
            vid = track.get("videoId", "")
            if vid and vid not in existing:
                self._queue.append(track)
                existing.add(vid)
        self.queueChanged.emit()

    @Slot(int)
    def remove_from_queue(self, index: int):
        if 0 <= index < len(self._queue) and index != self._queue_index:
            self._queue.pop(index)
            if index < self._queue_index:
                self._queue_index -= 1
            self.queueChanged.emit()

    @Slot()
    def clear_queue(self):
        if self._current_track:
            self._queue = [self._current_track]
            self._queue_index = 0
        else:
            self._queue = []
            self._queue_index = -1
        self.queueChanged.emit()

    def _load_current_track(self):
        if 0 <= self._queue_index < len(self._queue):
            self._loading_track = True
            self._loading = True
            self.loadingChanged.emit()
            self._current_track = self._queue[self._queue_index]
            self.currentTrackChanged.emit()
            self.queueChanged.emit()
            video_id = self._current_track.get("videoId", "")
            if self._offline_mode and not video_id:
                path = self._current_track.get("path", "")
                if path and os.path.exists(path):
                    self.audio_player.stop()
                    self.audio_player.play(path)
                    tooltip = f"{self._current_track.get('title', '')} - {self._current_track.get('artist', '')}"
                    self.tray_service.update_tooltip(tooltip)
                    return
            # Caminho online (YouTube)
            self._offline_mode = False
            if video_id:
                self.audio_player.stop()
                self.stream_service.get_stream_url(video_id)
                tooltip = f"{self._current_track.get('title', '')} - {self._current_track.get('artist', '')}"
                self.tray_service.update_tooltip(tooltip)

    @Slot()
    def download_current_as_mp3(self):
        track = self._current_track
        if not track:
            self.download_service._set("error", "Nenhuma musica tocando")
            return
        video_id = track.get("videoId", "")
        if not video_id:
            self.download_service._set("error", "Faixa sem videoId (nao e do YouTube)")
            return
        folder = self.settings_service.download_folder
        self.download_service.download_as_mp3(
            video_id,
            track.get("title", ""),
            track.get("artist", ""),
            folder,
        )

    @Slot()
    def pick_download_folder(self):
        """Abre o seletor de pasta nativo (confiavel no KDE/Wayland e
        Windows, via QFileDialog) e grava em settings. Usado por Settings
        e pelo botao de download."""
        start = str(self.settings_service.download_folder) or ""
        folder = QFileDialog.getExistingDirectory(
            None, "Escolha a pasta para salvar os MP3", start
        )
        if folder:
            self.settings_service.set_download_folder(folder)
            log.info("pasta de download definida: %s", folder)
        else:
            log.info("selecao de pasta cancelada pelo usuario")

    @Slot()
    def pick_and_download_mp3(self):
        """Se ja tem pasta configurada, baixa direto. Caso contrario, abre
        o seletor nativo e entao baixa a faixa que esta tocando."""
        if not self._current_track:
            self.download_service._set("error", "Nenhuma musica tocando")
            return
        if not self.settings_service.download_folder:
            self.pick_download_folder()
        if not self.settings_service.download_folder:
            # usuario cancelou a selecao de pasta: nao baixa
            return
        self.download_current_as_mp3()

    @Slot()
    def scan_offline(self):
        """Lista os arquivos de audio da pasta de download e monta a
        lista offline. Deriva artista/titulo do nome do arquivo
        (padrao 'Artista - Titulo' do download, mas aceita qualquer)."""
        folder = str(self.settings_service.download_folder) or ""
        tracks = []
        if folder and os.path.isdir(folder):
            try:
                entries = sorted(os.listdir(folder))
            except OSError:
                entries = []
            for fn in entries:
                if not fn.lower().endswith(self.OFFLINE_EXTS):
                    continue
                path = os.path.join(folder, fn)
                if not os.path.isfile(path):
                    continue
                name = os.path.splitext(fn)[0]
                artist = ""
                title = name
                if " - " in name:
                    artist, title = name.split(" - ", 1)
                # Capa: primeiro tenta .jpg/.png/.webp ao lado do audio;
                # se nao houver, extrai a capa embutida no proprio MP3.
                cover = self._cover_for(path, folder, name)
                tracks.append({
                    "title": title.strip(),
                    "artist": artist.strip(),
                    "path": path,
                    "filename": fn,
                    "thumbnail": cover,
                    "videoId": "",
                    "duration": "",
                })
        self._offline_tracks = tracks
        self.offlineTracksChanged.emit()

    def _cover_for(self, audio_path: str, folder: str, name: str) -> str:
        """Retorna a URL da capa para um arquivo offline.

        Tenta, em ordem:
          1. <nome>.jpg/.png/.webp/.jpeg ao lado do audio (padrao writethumbnail)
          2. capa embutida no proprio MP3 via parser da tag ID3 APIC
             (pega JPEG, PNG ou WebP independente de como o yt-dlp/ffmpeg
             embutiu -- funciona tanto nos downloads antigos quanto nos novos)
        O resultado e cacheado em _COVER_CACHE_DIR para nao re-extrair.
        """
        # 1) imagem ao lado
        for ext in (".jpg", ".jpeg", ".png", ".webp"):
            cand = os.path.join(folder, name + ext)
            if os.path.isfile(cand):
                return QUrl.fromLocalFile(cand).toString()
        # 2) capa embutida (ID3 APIC)
        try:
            cache_key = os.path.splitext(os.path.basename(audio_path))[0]
            os.makedirs(self._COVER_CACHE_DIR, exist_ok=True)
            data = open(audio_path, "rb").read()
            blob = _extract_apic(data)
            if blob:
                ext = _image_ext(blob)
                cached = os.path.join(self._COVER_CACHE_DIR, cache_key + ext)
                with open(cached, "wb") as fh:
                    fh.write(blob)
                return QUrl.fromLocalFile(cached).toString()
        except Exception as e:
            log.warning("Falha ao extrair capa de %s: %s", audio_path, e)
        return ""

    @Slot(int)
    def play_offline(self, index: int):
        """Toca o arquivo local na posicao index da lista offline."""
        if 0 <= index < len(self._offline_tracks):
            self._queue = list(self._offline_tracks)
            self._queue_index = index
            self._offline_mode = True
            self.offlineModeChanged.emit()
            self._load_current_track()

    @Slot()
    def shuffle_offline(self):
        """Embaralha a lista offline e comeca a tocar do inicio.

        Mantem a flag _offline_shuffle ligada para que, ao terminar a
        lista, o repeat (se ligado) reembaralhe em vez de repetir a mesma
        ordem. Se a lista estiver vazia, nao faz nada.
        """
        if not self._offline_tracks:
            return
        items = list(self._offline_tracks)
        rng = random.Random()
        rng.shuffle(items)
        self._offline_tracks = items
        self._offline_shuffle = True
        self.offlineTracksChanged.emit()
        self.offlineControlsChanged.emit()
        # comeca do inicio
        self._queue = list(self._offline_tracks)
        self._queue_index = 0
        self._offline_mode = True
        self.offlineModeChanged.emit()
        self._load_current_track()

    @Slot()
    def toggle_offline_repeat(self):
        """Liga/desliga a repeticao da lista offline."""
        self._offline_repeat = not self._offline_repeat
        self.offlineControlsChanged.emit()

    @staticmethod
    def _has_internet() -> bool:
        """Teste rapido de conectividade (socket TCP curto p/ o YouTube)."""
        import socket
        for host in ("music.youtube.com", "www.google.com"):
            try:
                sock = socket.create_connection((host, 443), timeout=3)
                sock.close()
                return True
            except OSError:
                continue
        return False

    @Slot()
    def pause(self):
        self._user_paused = True
        self.audio_player.pause()

    @Slot()
    def resume(self):
        if self._current_track:
            self._user_paused = False
            self.audio_player.resume()

    @Slot()
    def toggle_play(self):
        if self._is_playing:
            self.pause()
        else:
            self.resume()

    def _auto_next(self):
        if not self._queue:
            return
        if self._queue_index >= len(self._queue):
            self._queue_index = len(self._queue) - 1
        # Fim da fila offline: aplica shuffle/repeat ou faz transicao online
        if self._offline_mode and self._queue_index >= len(self._queue) - 1:
            self._offline_on_end()
            return
        if self._queue_index < len(self._queue) - 1:
            self._queue_index += 1
            self._load_current_track()
        else:
            self._generate_new_queue()

    def _offline_on_end(self):
        """Tratamento do fim da lista offline.

        - repeat ligado: reinicia a lista (reembaralhando se shuffle ligado)
        - repeat desligado: se houver internet, gera fila ONLINE a partir da
          ultima faixa tocada (busca artista+titulo -> videoId -> watch playlist);
          se nao houver internet, para.
        """
        if self._offline_repeat:
            if self._offline_shuffle:
                items = list(self._offline_tracks)
                random.Random().shuffle(items)
                self._offline_tracks = items
                self.offlineTracksChanged.emit()
            self._queue = list(self._offline_tracks)
            self._queue_index = 0
            self._load_current_track()
            return
        # sem repeat: tenta transicao para fila online (precisa de internet)
        last = self._current_track
        if not last:
            return
        if not self._has_internet():
            # sem internet e sem repeat: para a reproducao
            self._is_playing = False
            self.isPlayingChanged.emit()
            return
        artist = last.get("artist", "")
        title = last.get("title", "")
        video_id = self.music_service.search_video_id(artist, title)
        if not video_id:
            # nao achou a faixa online: para
            self._is_playing = False
            self.isPlayingChanged.emit()
            return
        # monta a faixa online a partir da ultima tocada e gera recomendacoes
        online_seed = {
            "videoId": video_id,
            "title": title,
            "artist": artist,
            "thumbnail": last.get("thumbnail", ""),
            "duration": last.get("duration", ""),
        }
        self._current_track = online_seed
        self.currentTrackChanged.emit()
        self._offline_mode = False
        self.offlineModeChanged.emit()
        self._generate_new_queue()

    @Slot()
    def next(self):
        if not self._queue:
            return
        if self._queue_index < len(self._queue) - 1:
            self._queue_index += 1
            self._load_current_track()
        else:
            self._generate_new_queue()

    def _generate_new_queue(self):
        if self._generating:
            return
        if not self._current_track:
            return
        self._generating = True
        video_id = self._current_track.get("videoId", "")
        if not video_id:
            self._generating = False
            return
        seed = int(time.time() * 1000)
        threading.Thread(
            target=self._generate_thread,
            args=(video_id, seed),
            daemon=True,
        ).start()

    def _generate_thread(self, video_id: str, seed: int):
        try:
            recs = self.music_service.get_recommendations(video_id, seed)
            if recs:
                existing_ids = {video_id}
                new_tracks = []
                for t in recs:
                    vid = t.get("videoId", "")
                    if vid and vid not in existing_ids:
                        new_tracks.append(t)
                        existing_ids.add(vid)
                if new_tracks:
                    self._newQueueReady.emit(new_tracks)
                    return
        except Exception:
            pass
        self._generating = False

    @Slot(list)
    def _on_new_queue_ready(self, tracks):
        self._queue = tracks
        self._queue_index = 0
        self._generating = False
        self._load_current_track()

    @Slot()
    def previous(self):
        if self._queue_index > 0:
            self._queue_index -= 1
            self._load_current_track()

    @Slot()
    def add_favorite(self):
        if self._current_track:
            self.favorites_service.add(self._current_track)

    @Slot("QVariant")
    def add_favorite_track(self, track: dict):
        self.favorites_service.add(track)

    @Slot(str)
    def remove_favorite(self, video_id: str):
        self.favorites_service.remove(video_id)

    @Slot("QVariant")
    def toggle_favorite(self, track: dict):
        video_id = track.get("videoId", "")
        if not video_id:
            return
        if self.favorites_service.is_favorite(video_id):
            self.favorites_service.remove(video_id)
        else:
            self.favorites_service.add(track)

    @Slot(int)
    def play_favorite(self, index: int):
        favs = self.favorites_service.get_all()
        if 0 <= index < len(favs):
            self._queue = [favs[index]]
            self._queue_index = 0
            self._load_current_track()

    @Slot(str)
    def set_view(self, view: str):
        self._view = view
        if view == "offline":
            self.scan_offline()
        self.viewChanged.emit()

    def _on_tray_close(self):
        self.audio_player.stop()
        self.stream_service.clear_cache()
        from PySide6.QtWidgets import QApplication
        QApplication.quit()

    @Property(list, notify=searchResultsChanged)
    def searchResults(self):
        return self._search_results

    @Property(str, notify=searchErrorChanged)
    def searchError(self):
        return self._search_error

    @Property("QVariant", notify=currentTrackChanged)
    def currentTrack(self):
        return self._current_track

    @Property(bool, notify=isPlayingChanged)
    def isPlaying(self):
        return self._is_playing

    @Property(bool, notify=loadingChanged)
    def isLoading(self):
        return self._loading

    @Property(str, notify=viewChanged)
    def currentView(self):
        return self._view

    @Property(list, notify=queueChanged)
    def queue(self):
        return self._queue

    @Property(int, notify=queueChanged)
    def queueIndex(self):
        return self._queue_index

    @Property(list, notify=spectrumChanged)
    def spectrum(self):
        return self._spectrum

    @Property(str, notify=downloadStatusChanged)
    def downloadStatus(self):
        return self.download_service.downloadStatus

    @Property(str, notify=downloadStatusChanged)
    def downloadMessage(self):
        return self.download_service.downloadMessage

    @Property(bool, notify=downloadStatusChanged)
    def isDownloading(self):
        return self.download_service.isDownloading

    @Property(str, notify=downloadStatusChanged)
    def downloadFolder(self):
        return self.settings_service.download_folder

    @Property(list, notify=offlineTracksChanged)
    def offline_tracks(self):
        return self._offline_tracks

    @Property(bool, notify=offlineTracksChanged)
    def offlineMode(self):
        return self._offline_mode

    @Property(bool, notify=offlineControlsChanged)
    def offlineShuffle(self):
        return self._offline_shuffle

    @Property(bool, notify=offlineControlsChanged)
    def offlineRepeat(self):
        return self._offline_repeat
