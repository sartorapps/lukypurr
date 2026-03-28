import os
from PySide6.QtCore import QObject, Slot, Signal
from PySide6.QtGui import QIcon, QPixmap, QColor, QPainter
from PySide6.QtWidgets import QSystemTrayIcon, QMenu, QApplication


class TrayService(QObject):
    showWindow = Signal()
    trayPlay = Signal()
    trayPause = Signal()
    trayNext = Signal()
    trayPrev = Signal()
    trayClose = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._tray = None
        self._menu = None

    def _create_icon(self):
        import sys
        if getattr(sys, "frozen", False):
            base = sys._MEIPASS
        else:
            base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        icon_path = os.path.join(base, "assets", "lukypurr_icon.png")
        if os.path.exists(icon_path):
            return QIcon(icon_path)
        icon_path = os.path.join(base, "assets", "icon.svg")
        if os.path.exists(icon_path):
            return QIcon(icon_path)
        pixmap = QPixmap(64, 64)
        pixmap.fill(QColor(29, 185, 84))
        return QIcon(pixmap)

    def setup(self):
        self._tray = QSystemTrayIcon()
        self._tray.setIcon(self._create_icon())
        self._tray.setToolTip("LukyPurr")

        self._menu = QMenu()

        play_action = self._menu.addAction("Play")
        play_action.triggered.connect(self.trayPlay.emit)

        pause_action = self._menu.addAction("Pause")
        pause_action.triggered.connect(self.trayPause.emit)

        self._menu.addSeparator()

        next_action = self._menu.addAction("Next")
        next_action.triggered.connect(self.trayNext.emit)

        prev_action = self._menu.addAction("Previous")
        prev_action.triggered.connect(self.trayPrev.emit)

        self._menu.addSeparator()

        show_action = self._menu.addAction("Show")
        show_action.triggered.connect(self.showWindow.emit)

        close_action = self._menu.addAction("Close")
        close_action.triggered.connect(self.trayClose.emit)

        self._tray.setContextMenu(self._menu)
        self._tray.activated.connect(self._on_activated)
        self._tray.show()

    def _on_activated(self, reason):
        if reason == QSystemTrayIcon.DoubleClick:
            self.showWindow.emit()

    @Slot(str)
    def update_tooltip(self, text: str):
        if self._tray:
            self._tray.setToolTip(text)

    def is_visible(self) -> bool:
        return self._tray is not None and self._tray.isVisible()

    def hide(self):
        if self._tray:
            self._tray.hide()
