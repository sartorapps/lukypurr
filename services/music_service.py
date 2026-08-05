from PySide6.QtCore import QObject, Slot, Signal
import ytmusicapi
import threading
import random


def extract_thumbnail(item: dict) -> str:
    thumbs = item.get("thumbnails", [])
    if thumbs:
        url = thumbs[-1].get("url", "")
        if url:
            return url
    video_id = item.get("videoId", "")
    if video_id:
        return f"https://img.youtube.com/vi/{video_id}/hqdefault.jpg"
    return ""


class MusicService(QObject):
    searchResults = Signal(list)
    searchFailed = Signal(str)

    def __init__(self):
        super().__init__()
        self.ytm = None
        self._init_event = threading.Event()
        threading.Thread(target=self._init_api, daemon=True).start()
        threading.Thread(target=self._self_update, daemon=True).start()

    def _self_update(self):
        """Auto-update silencioso do ytmusicapi no boot — a API do YouTube
        Music muda de formato com frequência e a lib desatualizada quebra
        (KeyError em get_watch_playlist, etc). Mesmo padrão do yt-dlp:
        o update vale no próximo boot (reload em runtime é arriscado)."""
        try:
            import sys
            if getattr(sys, "frozen", False):
                return
            import subprocess
            subprocess.run(
                [sys.executable, "-m", "pip", "install", "-q", "--upgrade", "ytmusicapi"],
                capture_output=True, timeout=90,
            )
        except Exception:
            pass

    def _init_api(self):
        try:
            self.ytm = ytmusicapi.YTMusic()
        except Exception:
            try:
                self.ytm = ytmusicapi.YTMusic(location="US")
            except Exception as e:
                self.ytm = None
                self.searchFailed.emit(f"Não foi possível iniciar a API do YouTube Music: {e}")
        finally:
            self._init_event.set()

    @Slot(str)
    def search(self, query: str):
        # Aguarda a API inicializar (thread em background) em vez de
        # retornar em silêncio — bug real: busca rápida antes do init
        # terminava sem fazer nada.
        self._init_event.wait(timeout=10)
        if not self.ytm:
            return
        threading.Thread(target=self._search_thread, args=(query,), daemon=True).start()

    def _search_thread(self, query: str):
        try:
            if not self.ytm:
                self.searchFailed.emit("API do YouTube Music não disponível. Verifique sua conexão.")
                return
            results = self.ytm.search(query, filter="songs")
            tracks = []
            for item in results[:20]:
                track = {
                    "videoId": item.get("videoId", ""),
                    "title": item.get("title", "Unknown"),
                    "artist": ", ".join(a.get("name", "") for a in item.get("artists", [])),
                    "thumbnail": extract_thumbnail(item),
                    "duration": item.get("duration", ""),
                }
                if track["videoId"]:
                    tracks.append(track)
            self.searchResults.emit(tracks)
        except Exception as e:
            self.searchFailed.emit(f"Falha na busca: {e}")

    def get_recommendations(self, video_id: str, seed: int = 0):
        if not self.ytm or not video_id:
            return []
        try:
            watch_playlist = self.ytm.get_watch_playlist(video_id, limit=15)
            tracks = []
            for item in watch_playlist.get("tracks", []):
                track = {
                    "videoId": item.get("videoId", ""),
                    "title": item.get("title", "Unknown"),
                    "artist": ", ".join(a.get("name", "") for a in item.get("artists", [])),
                    "thumbnail": extract_thumbnail(item),
                    "duration": item.get("length", ""),
                }
                if track["videoId"]:
                    tracks.append(track)

            if seed:
                rng = random.Random(seed)
                rng.shuffle(tracks)

            return tracks
        except Exception as e:
            import logging
            logging.getLogger("lukypurr.music").warning(
                "Falha ao gerar recomendações para %s: %s", video_id, e
            )
            return []
