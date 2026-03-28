import threading
import time
from PySide6.QtCore import QObject, Slot, Signal, Property, QTimer
from services.music_service import MusicService
from services.stream_service import StreamService
from services.audio_player import AudioPlayer
from services.favorites_service import FavoritesService
from services.tray_service import TrayService
from services.spectral_service import SpectralService
from services.settings_service import SettingsService
from services.theme_service import ThemeService


class Controller(QObject):
    searchResultsChanged = Signal()
    currentTrackChanged = Signal()
    queueChanged = Signal()
    isPlayingChanged = Signal()
    viewChanged = Signal()
    spectrumChanged = Signal()
    _newQueueReady = Signal(list)

    def __init__(self):
        super().__init__()
        self._search_results = []
        self._current_track = {}
        self._queue = []
        self._queue_index = -1
        self._is_playing = False
        self._user_paused = False
        self._loading_track = False
        self._view = "search"
        self._generating = False
        self._spectrum = []
        self._last_position = 0.0
        self._stuck_count = 0

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

        self.music_service.searchResults.connect(self._on_search_results)
        self.stream_service.streamUrlReady.connect(self._on_stream_ready)
        self.audio_player.stateChanged.connect(self._on_player_state)
        self.audio_player.pcmReady.connect(self.spectral_service.analyze_pcm)
        self.favorites_service.favoritesChanged.connect(self._on_favorites_changed)
        self.spectral_service.spectrumReady.connect(self._on_spectrum)
        self._newQueueReady.connect(self._on_new_queue_ready)

        self.tray_service.trayPlay.connect(self.resume)
        self.tray_service.trayPause.connect(self.pause)
        self.tray_service.trayNext.connect(self.next)
        self.tray_service.trayPrev.connect(self.previous)
        self.tray_service.trayClose.connect(self._on_tray_close)

    def setup_tray(self):
        self.tray_service.setup()

    @property
    def player_service(self):
        return self.audio_player

    @Slot(str)
    def search(self, query: str):
        self.music_service.search(query)

    def _on_search_results(self, results):
        self._search_results = results
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
            self._current_track = self._queue[self._queue_index]
            self.currentTrackChanged.emit()
            self.queueChanged.emit()
            video_id = self._current_track.get("videoId", "")
            if video_id:
                self.audio_player.stop()
                self.stream_service.get_stream_url(video_id)
                tooltip = f"{self._current_track.get('title', '')} - {self._current_track.get('artist', '')}"
                self.tray_service.update_tooltip(tooltip)

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
        if self._queue_index < len(self._queue) - 1:
            self._queue_index += 1
            self._load_current_track()
        else:
            self._generate_new_queue()

    @Slot()
    def next(self):
        if not self._queue:
            return
        self.audio_player.stop()
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
        self.viewChanged.emit()

    def _on_tray_close(self):
        self.audio_player.stop()
        self.stream_service.clear_cache()
        from PySide6.QtWidgets import QApplication
        QApplication.quit()

    @Property(list, notify=searchResultsChanged)
    def searchResults(self):
        return self._search_results

    @Property("QVariant", notify=currentTrackChanged)
    def currentTrack(self):
        return self._current_track

    @Property(bool, notify=isPlayingChanged)
    def isPlaying(self):
        return self._is_playing

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
