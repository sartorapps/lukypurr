import os
import re
import logging
import threading
from PySide6.QtCore import QObject, Slot, Signal, Property

import yt_dlp

log = logging.getLogger("lukypurr.download")

# ---- Constantes (regra sem-numeros-magicos) ----
MP3_BITRATE = "192"          # kbps
STATUS_IDLE = "idle"
STATUS_DOWNLOADING = "downloading"
STATUS_DONE = "done"
STATUS_ERROR = "error"
_DOWNLOAD_MSG_DONE = "Pronto"
_DOWNLOAD_MSG_NO_TARGET = "Nenhuma musica tocando"
_DOWNLOAD_MSG_NO_FOLDER = "Escolha a pasta em Settings"
_DOWNLOAD_MSG_BAD_FOLDER = "Pasta de destino invalida"
_DOWNLOAD_MSG_FAIL = "Falha ao baixar"

# Caracteres ilegais em nomes de arquivo (Windows + Linux)
_BAD_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def _safe_filename(name: str) -> str:
    cleaned = _BAD_CHARS.sub("_", name or "").strip().rstrip(".")
    return cleaned or "track"


class DownloadService(QObject):
    """Baixa a faixa do YouTube que esta tocando e salva como MP3.

    Reusa o mesmo yt-dlp do stream_service (nightly, funciona contra o
    bloqueio 403 atual do YouTube). A conversao pra MP3 usa o ffmpeg
    do sistema via postprocessor FFmpegExtractAudio.
    """

    downloadStatusChanged = Signal()

    def __init__(self):
        super().__init__()
        self._status = STATUS_IDLE
        self._message = ""

    def _set(self, status: str, message: str = ""):
        self._status = status
        self._message = message
        self.downloadStatusChanged.emit()

    @Property(str, notify=downloadStatusChanged)
    def downloadStatus(self):
        return self._status

    @Property(str, notify=downloadStatusChanged)
    def downloadMessage(self):
        return self._message

    @Property(bool, notify=downloadStatusChanged)
    def isDownloading(self):
        return self._status == STATUS_DOWNLOADING

    def download_as_mp3(self, video_id: str, title: str, artist: str, out_dir: str):
        log.info("download_as_mp3: video_id=%s out_dir=%r isdir=%s",
                 video_id, out_dir, os.path.isdir(out_dir) if out_dir else "vazio")
        if not video_id:
            self._set(STATUS_ERROR, _DOWNLOAD_MSG_NO_TARGET)
            return
        if not out_dir or not os.path.isdir(out_dir):
            self._set(STATUS_ERROR, _DOWNLOAD_MSG_NO_FOLDER if not out_dir else _DOWNLOAD_MSG_BAD_FOLDER)
            return
        threading.Thread(
            target=self._download_thread,
            args=(video_id, title, artist, out_dir),
            daemon=True,
        ).start()

    def _download_thread(self, video_id: str, title: str, artist: str, out_dir: str):
        try:
            self._set(STATUS_DOWNLOADING, "")
            url = f"https://www.youtube.com/watch?v={video_id}"

            base_name = f"{artist} - {title}".strip(" -") if artist else (title or "track")
            safe_name = _safe_filename(base_name)
            outtmpl = os.path.join(out_dir, f"{safe_name}.%(ext)s")

            ydl_opts = {
                "format": "bestaudio/best",
                "outtmpl": outtmpl,
                "quiet": True,
                "no_warnings": True,
                "postprocessors": [{
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": "mp3",
                    "preferredquality": MP3_BITRATE,
                }],
                "keepvideo": False,
            }

            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                ydl.download([url])

            self._set(STATUS_DONE, _DOWNLOAD_MSG_DONE)
        except Exception as e:
            log.warning("Falha no download MP3 (%s): %s", video_id, e)
            self._set(STATUS_ERROR, _DOWNLOAD_MSG_FAIL)
