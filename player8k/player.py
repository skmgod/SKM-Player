import os
import re
import subprocess
import sys

os.environ.setdefault("QT_MEDIA_BACKEND", "ffmpeg")

from PySide6.QtCore import QObject, Property, QStandardPaths, QUrl, Slot
from PySide6.QtGui import QFont, QIcon, QImage
from PySide6.QtMultimedia import QVideoSink
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication, QFileDialog

import subs
from ai_engine import AiEngine

FILTER = ("동영상 (*.mp4 *.mkv *.avi *.mov *.wmv *.webm *.ts *.m2ts *.mts *.flv *.m4v *.mpg *.mpeg *.3gp);;"
          "모든 파일 (*.*)")
SUB_FILTER = "자막 (*.srt *.smi *.sami *.vtt *.ass *.ssa);;모든 파일 (*.*)"
LIVE_CAPTIONS = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "System32", "LiveCaptions.exe")


CONFIG_DIR = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "Player64X")
KEYS_FILE = os.path.join(CONFIG_DIR, "keys.json")


def base_dir():
    return getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))


VIDEO_EXTS = (".mp4", ".mkv", ".avi", ".mov", ".wmv", ".webm", ".ts", ".m2ts", ".mts", ".f4v", ".3g2", ".asf", ".rm", ".rmvb", ".mxf",
              ".flv", ".m4v", ".mpg", ".mpeg", ".3gp", ".ogv", ".vob", ".divx")


def _natural(s):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", s)]


def expand_paths(paths):
    """파일/폴더 경로 목록 -> 동영상 파일 경로(자연 정렬, 중복 제거)"""
    found = []
    for p in paths:
        if os.path.isdir(p):
            for root, _, files in os.walk(p):
                for n in files:
                    if n.lower().endswith(VIDEO_EXTS):
                        found.append(os.path.join(root, n))
        elif os.path.isfile(p) and p.lower().endswith(VIDEO_EXTS):
            found.append(p)
    uniq = list(dict.fromkeys(os.path.abspath(x) for x in found))
    return sorted(uniq, key=_natural)


def to_urls(paths):
    return [QUrl.fromLocalFile(p).toString() for p in paths]


class Backend(QObject):
    def __init__(self, start_files=None):
        super().__init__()
        self._start = start_files or []

    @Property("QVariantList", constant=True)
    def startFiles(self):
        return self._start

    @Slot(result="QVariantList")
    def openDialog(self):
        paths, _ = QFileDialog.getOpenFileNames(None, "동영상 열기 (여러 개 선택 가능)", "", FILTER)
        return to_urls(sorted(paths, key=_natural))

    @Slot("QVariantList", result="QVariantList")
    def expandUrls(self, urls):
        """끌어놓은 파일/폴더 URL -> 재생할 동영상 URL 목록"""
        return to_urls(expand_paths([QUrl(u).toLocalFile() for u in urls]))

    @Slot(str, result="QVariantList")
    def findSubtitles(self, video_url):
        path = QUrl(video_url).toLocalFile()
        return subs.find_sidecars(path) if path else []

    @Slot(result="QVariantList")
    def openSubtitleDialog(self):
        paths, _ = QFileDialog.getOpenFileNames(None, "자막 파일 열기", "", SUB_FILTER)
        out = []
        for p in paths:
            try:
                out += subs.load_file(p)
            except Exception:
                pass
        return out

    @Slot(str, result="QVariantList")
    def loadSubtitleUrl(self, url):
        try:
            return subs.load_file(QUrl(url).toLocalFile())
        except Exception:
            return []

    @Slot(QVideoSink, str, int, str, result=str)
    def capture(self, sink, name, ms, fmt):
        """현재 프레임을 원본 해상도 PNG 로 저장하고 파일 이름을 돌려준다."""
        try:
            frame = sink.videoFrame()
            if not frame.isValid():
                print("capture: 유효한 프레임 없음", file=sys.stderr)
                return ""
            img = frame.toImage()
            if img.isNull():
                print("capture: 프레임 변환 실패", frame.pixelFormat(), frame.size(), file=sys.stderr)
                return ""
            folder = os.path.join(QStandardPaths.writableLocation(QStandardPaths.PicturesLocation), "Player64X")
            os.makedirs(folder, exist_ok=True)
            stem = re.sub(r'[\\/:*?"<>|]', "_", os.path.splitext(name)[0]) or "capture"
            t = f"{ms // 3600000:02d}-{ms // 60000 % 60:02d}-{ms // 1000 % 60:02d}-{ms % 1000:03d}"
            jpg = str(fmt).lower() in ("jpg", "jpeg")
            ext = "jpg" if jpg else "png"
            path = os.path.join(folder, f"{stem}_{t}.{ext}")
            n = 2
            while os.path.exists(path):
                path = os.path.join(folder, f"{stem}_{t}_{n}.{ext}")
                n += 1
            if img.hasAlphaChannel():
                img = img.convertToFormat(QImage.Format_RGB32)  # 불투명 영상: 알파 제거
            if img.save(path, "JPG", 95) if jpg else img.save(path, "PNG", 80):
                return os.path.basename(path)
            print("capture: 저장 실패", path, img.format(), img.size(), file=sys.stderr)
            return ""
        except Exception as e:  # 캡처 실패 원인은 콘솔에 남김
            print("capture failed:", repr(e), file=sys.stderr)
            return ""

    @Slot(str, result=str)
    def loadConfig(self, name):
        try:
            with open(os.path.join(CONFIG_DIR, os.path.basename(name)), "r", encoding="utf-8") as f:
                return f.read()
        except OSError:
            return "{}"

    @Slot(str, str)
    def saveConfig(self, name, text):
        try:
            os.makedirs(CONFIG_DIR, exist_ok=True)
            with open(os.path.join(CONFIG_DIR, os.path.basename(name)), "w", encoding="utf-8") as f:
                f.write(text)
        except OSError:
            pass

    @Slot(result=str)
    def loadKeys(self):
        try:
            with open(KEYS_FILE, "r", encoding="utf-8") as f:
                return f.read()
        except OSError:
            return "{}"

    @Slot(str)
    def saveKeys(self, text):
        try:
            os.makedirs(os.path.dirname(KEYS_FILE), exist_ok=True)
            with open(KEYS_FILE, "w", encoding="utf-8") as f:
                f.write(text)
        except OSError:
            pass

    @Slot(result=bool)
    def liveCaptions(self):
        """Windows 11 실시간 캡션(온디바이스 음성 인식)을 켠다."""
        if not os.path.isfile(LIVE_CAPTIONS):
            return False
        subprocess.Popen([LIVE_CAPTIONS], close_fds=True)
        return True


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Player 64X")
    f = QFont()
    f.setFamilies(["Segoe UI Variable Text", "Segoe UI", "Malgun Gothic"])
    f.setPixelSize(13)
    app.setFont(f)
    icon = os.path.join(base_dir(), "icon.png")
    if os.path.isfile(icon):
        app.setWindowIcon(QIcon(icon))

    backend = Backend(to_urls(expand_paths(sys.argv[1:])))
    engine = QQmlApplicationEngine()
    ai = AiEngine()
    app.aboutToQuit.connect(ai.shutdown)
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("ai", ai)
    engine.load(QUrl.fromLocalFile(os.path.join(base_dir(), "Main.qml")))
    if not engine.rootObjects():
        sys.exit(1)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
