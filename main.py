import os
import sys
import atexit
import logging

os.environ["QT_LOGGING_RULES"] = "qt.multimedia*=false"
os.environ["AV_LOG_LEVEL"] = "panic"
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Fusion"

# No modo empacotado (PyInstaller), __file__ aponta pro bundle temporário
# (_MEIPASS) que é apagado ao fechar — os RESOURCES ficam lá, mas o LOG
# precisa de um lugar permanente: a pasta do executável.
if getattr(sys, "frozen", False):
    RESOURCE_DIR = getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))
    BASE_DIR = os.path.dirname(os.path.abspath(sys.executable))
else:
    RESOURCE_DIR = BASE_DIR = os.path.dirname(os.path.abspath(__file__))

os.chdir(BASE_DIR)

# Logging em arquivo em vez de engolir stderr (o antigo dup2 pro /dev/null
# escondia TODOS os erros — o debug virava um inferno).
LOG_DIR = os.path.join(BASE_DIR, "logs")
os.makedirs(LOG_DIR, exist_ok=True)
_LOG_FILE = os.path.join(LOG_DIR, "lukypurr.log")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.FileHandler(_LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(sys.stderr),
    ],
)
log = logging.getLogger("lukypurr")
log.info("=== LukyPurr iniciando ===")

from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtGui import QIcon
from PySide6.QtCore import QTimer, QUrl
from controller import Controller


def get_icon_path():
    png_path = os.path.join(RESOURCE_DIR, "assets", "lukypurr_icon.png")
    if os.path.exists(png_path):
        return png_path
    return os.path.join(RESOURCE_DIR, "assets", "icon.svg")


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

    qml_path = os.path.join(RESOURCE_DIR, "ui", "Main.qml")
    engine.load(QUrl.fromLocalFile(qml_path))

    if not engine.rootObjects():
        log.critical("Falha ao carregar QML — sem rootObjects. Ver logs acima.")
        sys.exit(-1)

    QTimer.singleShot(100, ctrl.setup_tray)

    exit_code = app.exec()
    ctrl.audio_player.stop()
    ctrl.spectral_service.cleanup()
    log.info("=== LukyPurr encerrando (exit %s) ===", exit_code)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
