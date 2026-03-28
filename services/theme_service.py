from PySide6.QtCore import QObject, Slot, Signal, Property
from platformdirs import user_data_dir
import json
import os
import sys


class ThemeService(QObject):
    themeChanged = Signal()
    currentThemeChanged = Signal()

    def __init__(self):
        super().__init__()
        if getattr(sys, "frozen", False):
            base = sys._MEIPASS
        else:
            base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        self._themes_dir = os.path.join(base, "themes")
        self._available = self._load_all_themes()
        data_dir = user_data_dir("LukyPurr", "LukyPurr")
        os.makedirs(data_dir, exist_ok=True)
        self._settings_file = os.path.join(data_dir, "settings.json")
        self._current = self._load_current_theme()
        self._data = self._get_theme_data(self._current)

    def _load_all_themes(self):
        themes = []
        if os.path.isdir(self._themes_dir):
            for f in sorted(os.listdir(self._themes_dir)):
                if f.endswith(".json"):
                    path = os.path.join(self._themes_dir, f)
                    try:
                        with open(path, "r", encoding="utf-8") as fh:
                            data = json.load(fh)
                            data["_file"] = f.replace(".json", "")
                            themes.append(data)
                    except Exception:
                        pass
        return themes

    def _load_current_theme(self):
        try:
            if os.path.exists(self._settings_file):
                with open(self._settings_file, "r", encoding="utf-8") as f:
                    settings = json.load(f)
                    return settings.get("theme", "dark_green")
        except Exception:
            pass
        return "dark_green"

    def _save_current_theme(self, theme_id: str):
        try:
            settings = {}
            if os.path.exists(self._settings_file):
                with open(self._settings_file, "r", encoding="utf-8") as f:
                    settings = json.load(f)
            settings["theme"] = theme_id
            with open(self._settings_file, "w", encoding="utf-8") as f:
                json.dump(settings, f, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def _get_theme_data(self, theme_id: str):
        for t in self._available:
            if t.get("_file") == theme_id:
                return t
        return self._available[0] if self._available else {}

    @Slot(str)
    def set_theme(self, theme_id: str):
        self._current = theme_id
        self._data = self._get_theme_data(theme_id)
        self._save_current_theme(theme_id)
        self.currentThemeChanged.emit()
        self.themeChanged.emit()

    def _prop(self, key, default=""):
        return self._data.get(key, default)

    @Property(str, notify=currentThemeChanged)
    def current_theme(self):
        return self._current

    @Property(list, notify=themeChanged)
    def available_themes(self):
        return [{
            "id": t.get("_file", ""),
            "name": t.get("name", ""),
            "type": t.get("type", "dark"),
            "bg": t.get("bg_main", "#121212"),
            "accent": t.get("accent", "#1DB954"),
            "text": t.get("text_primary", "#FFFFFF"),
            "radius": t.get("radius", "6"),
        } for t in self._available]

    @Property(str, notify=themeChanged)
    def bg_main(self): return self._prop("bg_main", "#121212")

    @Property(str, notify=themeChanged)
    def bg_sidebar(self): return self._prop("bg_sidebar", "#000000")

    @Property(str, notify=themeChanged)
    def bg_surface(self): return self._prop("bg_surface", "#181818")

    @Property(str, notify=themeChanged)
    def bg_card(self): return self._prop("bg_card", "#1A1A1A")

    @Property(str, notify=themeChanged)
    def bg_hover(self): return self._prop("bg_hover", "#282828")

    @Property(str, notify=themeChanged)
    def bg_input(self): return self._prop("bg_input", "#2A2A2A")

    @Property(str, notify=themeChanged)
    def text_primary(self): return self._prop("text_primary", "#FFFFFF")

    @Property(str, notify=themeChanged)
    def text_secondary(self): return self._prop("text_secondary", "#AAAAAA")

    @Property(str, notify=themeChanged)
    def text_muted(self): return self._prop("text_muted", "#666666")

    @Property(str, notify=themeChanged)
    def accent(self): return self._prop("accent", "#1DB954")

    @Property(str, notify=themeChanged)
    def accent_hover(self): return self._prop("accent_hover", "#1ed760")

    @Property(str, notify=themeChanged)
    def accent_dark(self): return self._prop("accent_dark", "#17a34a")

    @Property(str, notify=themeChanged)
    def border(self): return self._prop("border", "#333333")

    @Property(str, notify=themeChanged)
    def player_bg(self): return self._prop("player_bg", "#181818")

    @Property(str, notify=themeChanged)
    def button_bg(self): return self._prop("button_bg", "#333333")

    @Property(str, notify=themeChanged)
    def button_text(self): return self._prop("button_text", "#FFFFFF")

    @Property(str, notify=themeChanged)
    def icon_accent(self): return self._prop("icon_accent", "#AAAAAA")

    @Property(str, notify=themeChanged)
    def icon_accent_active(self): return self._prop("icon_accent_active", "#1DB954")

    @Property(str, notify=themeChanged)
    def badge_bg(self): return self._prop("badge_bg", "#1DB954")

    @Property(str, notify=themeChanged)
    def badge_text(self): return self._prop("badge_text", "#000000")

    @Property(str, notify=themeChanged)
    def scrollbar(self): return self._prop("scrollbar", "#333333")

    @Property(int, notify=themeChanged)
    def radius(self):
        try:
            return int(self._prop("radius", "6"))
        except Exception:
            return 6
