from PySide6.QtCore import QObject, Slot, Signal
import yt_dlp
import threading
import tempfile
import os
import shutil


MAX_CACHE = 20


def cleanup_old_temp_dirs():
    temp_root = tempfile.gettempdir()
    for name in os.listdir(temp_root):
        if name.startswith("lukypurr_"):
            try:
                shutil.rmtree(os.path.join(temp_root, name))
            except Exception:
                pass


cleanup_old_temp_dirs()


class StreamService(QObject):
    streamUrlReady = Signal(str, str)

    def __init__(self):
        super().__init__()
        self._cache = {}
        self._lock = threading.Lock()
        self._temp_dir = tempfile.mkdtemp(prefix=f"lukypurr_{os.getpid()}_")

    @Slot(str)
    def get_stream_url(self, video_id: str):
        with self._lock:
            if video_id in self._cache:
                path = self._cache[video_id]
                if os.path.exists(path):
                    self.streamUrlReady.emit(video_id, path)
                    return
        threading.Thread(target=self._download_thread, args=(video_id,), daemon=True).start()

    def _download_thread(self, video_id: str):
        try:
            with self._lock:
                temp_dir = self._temp_dir

            url = f"https://www.youtube.com/watch?v={video_id}"
            ydl_opts = {
                "format": "bestaudio[ext=m4a]/bestaudio/best",
                "outtmpl": os.path.join(temp_dir, f"{video_id}.%(ext)s"),
                "quiet": True,
                "no_warnings": True,
            }
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                downloaded = ydl.prepare_filename(info)

            if downloaded and os.path.exists(downloaded):
                with self._lock:
                    if len(self._cache) >= MAX_CACHE:
                        old_key = next(iter(self._cache))
                        old_path = self._cache.pop(old_key, "")
                        try:
                            if old_path and os.path.exists(old_path):
                                os.remove(old_path)
                        except Exception:
                            pass
                    self._cache[video_id] = downloaded
                self.streamUrlReady.emit(video_id, downloaded)
            else:
                self.streamUrlReady.emit(video_id, "")
        except Exception:
            self.streamUrlReady.emit(video_id, "")

    def clear_cache(self):
        with self._lock:
            try:
                if os.path.exists(self._temp_dir):
                    shutil.rmtree(self._temp_dir)
            except Exception:
                pass
            self._cache.clear()
            self._temp_dir = tempfile.mkdtemp(prefix=f"lukypurr_{os.getpid()}_")
