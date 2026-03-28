import math
import numpy as np
from PySide6.QtCore import QObject, Signal


# Category weights applied AFTER normalization
CATEGORY_WEIGHTS = {
    "sub_bass": 1.1,
    "bass": 1.1,
    "low_mid": 1.0,
    "vocal": 1.3,
    "presence": 1.0,
    "treble": 0.9,
}


def classify_freq(hz: float) -> str:
    if hz < 80:
        return "sub_bass"
    elif hz < 250:
        return "bass"
    elif hz < 500:
        return "low_mid"
    elif hz < 2000:
        return "vocal"
    elif hz < 6000:
        return "presence"
    else:
        return "treble"


class SpectralService(QObject):
    spectrumReady = Signal(list)

    def __init__(self):
        super().__init__()
        self._num_bands = 40
        self._sample_rate = 44100
        self._fft_size = 2048
        self._smoothed = [0.0] * self._num_bands
        self._history = []
        self._history_max = 40
        self._band_categories = []
        self._freqs = np.fft.rfftfreq(self._fft_size, d=1.0 / self._sample_rate)
        self._init_band_categories()

    def _init_band_categories(self):
        num_bins = len(self._freqs)
        band_edges = self._build_band_edges(num_bins)
        self._band_categories = []
        for i in range(self._num_bands):
            start = band_edges[i]
            end = band_edges[i + 1]
            if end <= start:
                end = start + 1
            band_freq = float(np.mean(self._freqs[start:end]))
            category = classify_freq(band_freq)
            self._band_categories.append(category)

    def analyze_pcm(self, pcm_data: np.ndarray):
        if len(pcm_data) < 64:
            return

        rms = float(np.sqrt(np.mean(pcm_data ** 2)))
        if rms < 0.005:
            self._smoothed = [s * 0.85 for s in self._smoothed]
            self.spectrumReady.emit(list(self._smoothed))
            return

        # Normalize to fixed FFT size
        if len(pcm_data) > self._fft_size:
            pcm_data = pcm_data[:self._fft_size]
        elif len(pcm_data) < self._fft_size:
            pcm_data = np.pad(pcm_data, (0, self._fft_size - len(pcm_data)))

        # FFT with real frequency mapping
        window = np.hanning(len(pcm_data))
        windowed = pcm_data * window
        spectrum = np.fft.rfft(windowed)
        magnitudes = np.abs(spectrum)
        freqs = np.fft.rfftfreq(len(pcm_data), d=1.0 / self._sample_rate)

        # Map FFT bins to bands using real frequency edges
        num_bins = len(magnitudes)
        band_edges = self._build_band_edges(num_bins)

        bands = []
        for i in range(self._num_bands):
            start = band_edges[i]
            end = band_edges[i + 1]
            if end <= start:
                end = start + 1
            chunk = magnitudes[start:end]
            energy = float(np.mean(chunk))
            bands.append(energy)

        bands = self._interpolate_zeros(bands)

        # Dynamic normalization using history
        self._history.append(bands)
        if len(self._history) > self._history_max:
            self._history.pop(0)

        all_vals = [v for frame in self._history for v in frame]
        ref = float(np.percentile(all_vals, 90))
        if ref < 1.0:
            ref = 1.0

        # Normalize and compress
        normalized = []
        for b in bands:
            ratio = b / ref
            if ratio < 0.02:
                normalized.append(0.0)
                continue
            ratio = min(ratio, 1.0)
            compressed = ratio ** 0.3
            normalized.append(compressed * 0.7)

        # Apply category-based weighting
        weighted = []
        for i, val in enumerate(normalized):
            cat = self._band_categories[i] if i < len(self._band_categories) else "low_mid"
            weight = CATEGORY_WEIGHTS.get(cat, 1.0)
            weighted.append(min(1.0, val * weight))

        # Temporal smoothing
        for i in range(self._num_bands):
            self._smoothed[i] = self._smoothed[i] * 0.65 + weighted[i] * 0.35

        result = [max(0.0, min(0.85, v)) for v in self._smoothed]
        self.spectrumReady.emit(result)

    def _build_band_edges(self, num_bins):
        edges = []
        min_bin = 1
        max_bin = max(num_bins - 1, 2)
        log_min = math.log10(min_bin)
        log_max = math.log10(max_bin)
        for i in range(self._num_bands + 1):
            frac = i / self._num_bands
            log_val = log_min + frac * (log_max - log_min)
            bin_idx = int(round(10 ** log_val))
            bin_idx = max(min_bin, min(bin_idx, max_bin))
            edges.append(bin_idx)
        for i in range(1, len(edges)):
            if edges[i] <= edges[i - 1]:
                edges[i] = edges[i - 1] + 1
        if edges[-1] > num_bins:
            edges[-1] = num_bins
        return edges

    def _interpolate_zeros(self, bands):
        result = list(bands)
        for i in range(len(result)):
            if result[i] <= 0.001:
                left = 0.0
                right = 0.0
                for j in range(i - 1, -1, -1):
                    if result[j] > 0.001:
                        left = result[j]
                        break
                for j in range(i + 1, len(result)):
                    if result[j] > 0.001:
                        right = result[j]
                        break
                if left > 0 and right > 0:
                    result[i] = (left + right) / 2.0
                elif left > 0:
                    result[i] = left * 0.5
                elif right > 0:
                    result[i] = right * 0.5
        return result

    def start(self):
        pass

    def stop(self):
        pass

    def cleanup(self):
        pass
