from PySide6.QtCore import QObject, Slot, Signal
import yt_dlp
import threading
import tempfile
import os
import shutil
import sys
import logging

log = logging.getLogger("lukypurr.stream")

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
        # YouTube muda o tempo todo; yt-dlp desatualizado = stream quebrado.
        # Atualiza em background, silencioso, sem travar o boot do app.
        threading.Thread(target=self._self_update, daemon=True).start()

    def _self_update(self):
        try:
            if getattr(sys, "frozen", False):
                # Binário congelado (PyInstaller): auto-update via pip quebraria
                # o bundle. Deixar quieto.
                return
            old = yt_dlp.version.__version__
            try:
                # API nova: yt_dlp.update virou módulo com classe Updater.
                from yt_dlp.update import Updater
                ydl = yt_dlp.YoutubeDL({"quiet": True, "no_warnings": True})
                updated = Updater(ydl).update()
            except Exception as e:
                # Instalado via pip: o auto-update interno é bloqueado, o yt-dlp
                # manda atualizar pelo próprio pip. Fallback silencioso.
                log.debug("auto-update interno indisponivel (%s) — tentando pip", e)
                import subprocess
                r = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "-q", "--upgrade", "yt-dlp"],
                    capture_output=True, timeout=60,
                )
                updated = r.returncode == 0
            new = yt_dlp.version.__version__
            if updated and old != new:
                log.info("yt-dlp atualizado: %s -> %s", old, new)
            else:
                log.debug("yt-dlp ja na versao mais recente (%s)", old)
        except Exception as e:
            log.warning("Falha ao atualizar yt-dlp: %s", e)

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
