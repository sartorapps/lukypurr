from PySide6.QtCore import QObject, Slot, Signal
from platformdirs import user_data_dir
import json
import os


class FavoritesService(QObject):
    favoritesChanged = Signal(list)

    def __init__(self):
        super().__init__()
        data_dir = user_data_dir("LukyPurr", "LukyPurr")
        os.makedirs(data_dir, exist_ok=True)
        self._file = os.path.join(data_dir, "favorites.json")
        self._favorites = self._load()

    def _load(self) -> list:
        try:
            if os.path.exists(self._file):
                with open(self._file, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception:
            pass
        return []

    def _save(self):
        try:
            with open(self._file, "w", encoding="utf-8") as f:
                json.dump(self._favorites, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    @Slot("QVariant")
    def add(self, track: dict):
        video_id = track.get("videoId", "")
        if not video_id:
            return
        for fav in self._favorites:
            if fav.get("videoId") == video_id:
                return
        self._favorites.append(track)
        self._save()
        self.favoritesChanged.emit(self._favorites)

    @Slot(str)
    def remove(self, video_id: str):
        self._favorites = [f for f in self._favorites if f.get("videoId") != video_id]
        self._save()
        self.favoritesChanged.emit(self._favorites)

    @Slot(str, result=bool)
    def is_favorite(self, video_id: str) -> bool:
        return any(f.get("videoId") == video_id for f in self._favorites)

    @Slot(result="QVariantList")
    def get_all(self) -> list:
        return self._favorites
