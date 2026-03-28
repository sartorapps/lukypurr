from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, QTimer
import numpy as np
import os


class AudioPlayer(QObject):
    stateChanged = Signal(str)
    positionChanged = Signal(float)
    durationChanged = Signal(float)
    volumeChanged = Signal(float)
    pcmReady = Signal(object)

    def __init__(self):
        super().__init__()
        self._state = "stopped"
        self._position = 0.0
        self._duration = 0.0
        self._volume = 80.0
        self._user_paused = False
        self._player = None
        self._audio_out = None
        self._decoder = None
        self._initialized = False

        self._pcm_buffer = np.array([], dtype=np.float32)
        self._pcm_rate = 44100
        self._emit_chunk = 4096

        self._poll_timer = QTimer()
        self._poll_timer.setInterval(250)
        self._poll_timer.timeout.connect(self._poll)

        self._emit_timer = QTimer()
        self._emit_timer.setInterval(50)
        self._emit_timer.timeout.connect(self._emit_chunk_pcm)

    def _ensure_init(self):
        if self._initialized:
            return
        self._initialized = True
        try:
            from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
            self._player = QMediaPlayer()
            self._audio_out = QAudioOutput()
            self._player.setAudioOutput(self._audio_out)
            self._player.playbackStateChanged.connect(self._on_player_state)
        except Exception:
            pass

        try:
            from PySide6.QtMultimedia import QAudioDecoder
            self._decoder = QAudioDecoder()
            self._decoder.bufferReady.connect(self._on_buffer_ready)
            self._decoder.finished.connect(self._on_decoder_finished)
        except Exception:
            self._decoder = None

    def _poll(self):
        if not self._player:
            return
        try:
            pos = self._player.position() / 1000.0
            if pos != self._position:
                self._position = pos
                self.positionChanged.emit(self._position)
            dur = self._player.duration() / 1000.0
            if dur != self._duration and dur > 0:
                self._duration = dur
                self.durationChanged.emit(self._duration)
        except Exception:
            pass

    def _emit_chunk_pcm(self):
        if len(self._pcm_buffer) == 0:
            return
        if self._state != "playing":
            return

        sample_pos = int(self._position * self._pcm_rate)
        if sample_pos >= len(self._pcm_buffer):
            return
        if sample_pos < 0:
            sample_pos = 0

        end = sample_pos + self._emit_chunk
        if end > len(self._pcm_buffer):
            end = len(self._pcm_buffer)
        chunk = self._pcm_buffer[sample_pos:end]
        if len(chunk) > 0:
            self.pcmReady.emit(chunk)

    def _on_player_state(self, qs):
        try:
            from PySide6.QtMultimedia import QMediaPlayer as QMP
            if qs == QMP.PlaybackState.PlayingState:
                self._state = "playing"
                self._poll_timer.start()
                self._emit_timer.start()
            elif qs == QMP.PlaybackState.PausedState:
                self._state = "paused"
                self._poll_timer.stop()
                self._emit_timer.stop()
            else:
                self._state = "stopped"
                self._poll_timer.stop()
                self._emit_timer.stop()
            self.stateChanged.emit(self._state)
        except Exception:
            pass

    def _on_decoder_finished(self):
        pass

    def _on_buffer_ready(self):
        if not self._decoder:
            return
        try:
            buf = self._decoder.read()
            if not buf.isValid():
                return

            from PySide6.QtMultimedia import QAudioFormat
            fmt = buf.format()
            raw = buf.data()
            sample_fmt = fmt.sampleFormat()

            if sample_fmt == QAudioFormat.SampleFormat.Int16:
                pcm = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
            elif sample_fmt == QAudioFormat.SampleFormat.Int32:
                pcm = np.frombuffer(raw, dtype=np.int32).astype(np.float32) / 2147483648.0
            elif sample_fmt == QAudioFormat.SampleFormat.Float:
                pcm = np.frombuffer(raw, dtype=np.float32)
            elif sample_fmt == QAudioFormat.SampleFormat.UInt8:
                pcm = (np.frombuffer(raw, dtype=np.uint8).astype(np.float32) - 128.0) / 128.0
            else:
                pcm = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0

            channels = fmt.channelCount()
            if channels > 1 and len(pcm) >= channels:
                pcm = pcm.reshape(-1, channels).mean(axis=1)

            if len(pcm) > 0:
                self._pcm_buffer = np.concatenate([self._pcm_buffer, pcm])
        except Exception:
            pass

    def play(self, url: str):
        self._ensure_init()
        self._pcm_buffer = np.array([], dtype=np.float32)
        if not self._player:
            return
        try:
            self._player.stop()
        except Exception:
            pass
        if self._decoder:
            try:
                self._decoder.stop()
            except Exception:
                pass
        self._position = 0.0
        self._duration = 0.0

        is_local = os.path.exists(url)
        if is_local:
            qurl = QUrl.fromLocalFile(url)
        else:
            qurl = QUrl(url)

        self._player.setSource(qurl)
        self._player.play()

        if self._decoder:
            try:
                self._decoder.setSource(qurl)
                self._decoder.start()
            except Exception:
                pass

    @Slot()
    def pause(self):
        self._user_paused = True
        if self._player:
            self._player.pause()

    @Slot()
    def resume(self):
        self._user_paused = False
        if self._player:
            self._player.play()

    @Slot()
    def stop(self):
        self._poll_timer.stop()
        self._emit_timer.stop()
        self._pcm_buffer = np.array([], dtype=np.float32)
        if self._player:
            self._player.stop()
        if self._decoder:
            try:
                self._decoder.stop()
            except Exception:
                pass

    @Slot(float)
    def seek(self, seconds: float):
        if self._player:
            self._player.setPosition(int(seconds * 1000))

    @Slot(float)
    def set_volume(self, vol: float):
        self._volume = max(0.0, min(100.0, vol))
        if self._audio_out:
            self._audio_out.setVolume(self._volume / 100.0)
        self.volumeChanged.emit(self._volume)

    @Property(str, notify=stateChanged)
    def state(self):
        return self._state

    @Property(float, notify=positionChanged)
    def position(self):
        return self._position

    @Property(float, notify=durationChanged)
    def duration(self):
        return self._duration

    @Property(float, notify=volumeChanged)
    def volume(self):
        return self._volume
