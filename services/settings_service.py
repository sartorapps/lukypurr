from PySide6.QtCore import QObject, Slot, Signal, Property
from platformdirs import user_data_dir
import json
import os


class SettingsService(QObject):
    settingsChanged = Signal()
    gradientColorChanged = Signal()
    gradientIntensityChanged = Signal()
    gradientOpacityChanged = Signal()

    DEFAULTS = {
        "gradient_color": "#1DB954",
        "gradient_intensity": 60,
        "gradient_opacity": 60,
    }

    def __init__(self):
        super().__init__()
        data_dir = user_data_dir("LukyPurr", "LukyPurr")
        os.makedirs(data_dir, exist_ok=True)
        self._file = os.path.join(data_dir, "settings.json")
        self._data = self._load()

    def _load(self):
        try:
            if os.path.exists(self._file):
                with open(self._file, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass
        return dict(self.DEFAULTS)

    def _save(self):
        try:
            with open(self._file, "w", encoding="utf-8") as f:
                json.dump(self._data, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    @Slot(str)
    def set_gradient_color(self, color: str):
        self._data["gradient_color"] = color
        self._save()
        self.gradientColorChanged.emit()
        self.settingsChanged.emit()

    @Slot(float)
    def set_gradient_intensity(self, value: float):
        self._data["gradient_intensity"] = max(0, min(100, value))
        self._save()
        self.gradientIntensityChanged.emit()
        self.settingsChanged.emit()

    @Property(str, notify=gradientColorChanged)
    def gradient_color(self):
        return self._data.get("gradient_color", self.DEFAULTS["gradient_color"])

    @Property(float, notify=gradientIntensityChanged)
    def gradient_intensity(self):
        return self._data.get("gradient_intensity", self.DEFAULTS["gradient_intensity"])

    @Slot(float)
    def set_gradient_opacity(self, value: float):
        self._data["gradient_opacity"] = max(5, min(100, value))
        self._save()
        self.gradientOpacityChanged.emit()
        self.settingsChanged.emit()

    @Property(float, notify=gradientOpacityChanged)
    def gradient_opacity(self):
        return self._data.get("gradient_opacity", self.DEFAULTS["gradient_opacity"])
