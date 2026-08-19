from PySide6.QtCore import QObject, Slot, Signal
import yt_dlp
import threading
import tempfile
import os
import json
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
                # o bundle. Deixar quieto. O bundle embute o yt-dlp fixo do build.
                return

            old = yt_dlp.version.__version__
            log.debug("yt-dlp antes do auto-update: %s", old)

            # O release estável do PyPI (2026.7.4) está QUEBRADO contra o bloqueio
            # 403 atual do YouTube. O conserto só existe no canal NIGHTLY. Por isso
            # NÃO usamos `pip install --upgrade yt-dlp` (voltaria pro release quebrado
            # e reverteria qualquer nightly instalado). Baixamos o tarball do nightly
            # direto do GitHub e reinstalamos no venv (idempotente, sem sudo).
            import tempfile
            import urllib.request

            # Tag do nightly: pegamos a mais recente via API do GitHub.
            try:
                api = "https://api.github.com/repos/yt-dlp/yt-dlp-nightly-builds/releases/latest"
                with urllib.request.urlopen(api, timeout=30) as resp:
                    data = json.loads(resp.read().decode())
                tag = data["tag_name"]
            except Exception as e:
                log.warning("Nao consegui descobrir o nightly mais recente (%s) — mantendo atual", e)
                return

            if old.startswith(tag.split(".")[0]):
                # old já é esse nightly (ex: 2026.08.18... == tag 2026.08.18.122307)
                log.debug("yt-dlp ja e o nightly %s", old)
                return

            tarball_url = f"https://github.com/yt-dlp/yt-dlp-nightly-builds/releases/download/{tag}/yt-dlp.tar.gz"
            tmp = os.path.join(tempfile.gettempdir(), f"lukypurr_yt_dlp_{tag}.tar.gz")
            try:
                urllib.request.urlretrieve(tarball_url, tmp)
                import subprocess
                r = subprocess.run(
                    [sys.executable, "-m", "pip", "install", "--force-reinstall",
                     "--no-deps", "-q", tmp],
                    capture_output=True, timeout=120,
                )
                if r.returncode != 0:
                    log.warning("Falha ao instalar nightly %s (pip rc=%s)", tag, r.returncode)
                    return
            finally:
                try:
                    os.remove(tmp)
                except Exception:
                    pass

            new = yt_dlp.version.__version__
            log.info("yt-dlp atualizado para nightly: %s -> %s", old, new)
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
