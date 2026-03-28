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

    def __init__(self):
        super().__init__()
        self.ytm = None
        threading.Thread(target=self._init_api, daemon=True).start()

    def _init_api(self):
        try:
            self.ytm = ytmusicapi.YTMusic()
        except Exception:
            try:
                self.ytm = ytmusicapi.YTMusic(location="US")
            except Exception as e:
                self.ytm = None

    @Slot(str)
    def search(self, query: str):
        if not self.ytm:
            return
        threading.Thread(target=self._search_thread, args=(query,), daemon=True).start()

    def _search_thread(self, query: str):
        try:
            if not self.ytm:
                self._init_api()
            if not self.ytm:
                self.searchResults.emit([])
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
            self.searchResults.emit([])

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
        except Exception:
            return []
