import os
import sys
import io
import atexit

os.environ["QT_LOGGING_RULES"] = "qt.multimedia*=false"
os.environ["AV_LOG_LEVEL"] = "quiet"
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"

base_dir = os.path.dirname(os.path.abspath(__file__))
os.chdir(base_dir)

from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtGui import QIcon
from PySide6.QtCore import QTimer, QUrl
from controller import Controller


def get_icon_path():
    png_path = os.path.join(base_dir, "assets", "lukypurr_icon.png")
    if os.path.exists(png_path):
        return png_path
    return os.path.join(base_dir, "assets", "icon.svg")


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("LukyPurr")
    app.setOrganizationName("LukyPurr")
    app.setQuitOnLastWindowClosed(False)
    app.setWindowIcon(QIcon(get_icon_path()))

    ctrl = Controller()
    atexit.register(ctrl.stream_service.clear_cache)

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("ctrl", ctrl)
    engine.rootContext().setContextProperty("favoritesService", ctrl.favorites_service)
    engine.rootContext().setContextProperty("playerService", ctrl.audio_player)
    engine.rootContext().setContextProperty("trayService", ctrl.tray_service)
    engine.rootContext().setContextProperty("settingsService", ctrl.settings_service)
    engine.rootContext().setContextProperty("theme", ctrl.theme_service)

    qml_path = os.path.join(base_dir, "ui", "Main.qml")
    engine.load(QUrl.fromLocalFile(qml_path))

    if not engine.rootObjects():
        sys.exit(-1)

    QTimer.singleShot(100, ctrl.setup_tray)

    exit_code = app.exec()
    ctrl.audio_player.stop()
    ctrl.spectral_service.cleanup()
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
