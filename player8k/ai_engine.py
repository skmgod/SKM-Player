"""AI 화질개선 엔진: GPU 작업 프로세스(ai_worker.py)를 띄우고 프레임을 주고받는다.

- 실시간 모드: 재생 중인 프레임을 보내고, 받은 고화질 프레임을 두 번째 VideoOutput 에 표시
- AI 캡처 모드: 현재 장면 1장을 키워서 PNG 로 저장
"""
import os
import re
import struct
import subprocess
import sys
import threading
import time

from PySide6.QtCore import QObject, Property, QStandardPaths, QTimer, Signal, Slot
from PySide6.QtGui import QImage
from PySide6.QtMultimedia import QVideoFrame, QVideoSink

HDR = struct.Struct("<4sBBBBII")
RT_MAX_PIXELS = 450_000        # 실시간 AI 입력 한도 (약 854x480). 그보다 크면 실시간 불가
RT_MAX_SIDE = 2560             # 실시간 출력 긴 변 한도
CAP_MAX_SIDE = 8192            # AI 캡처 출력 긴 변 한도
MODEL_NAMES = {0: "실사", 1: "애니"}
CREATE_NO_WINDOW = 0x08000000


def base_dir():
    return getattr(sys, "_MEIPASS", os.path.dirname(os.path.abspath(__file__)))


def model_dirs():
    exe_dir = os.path.dirname(sys.executable if getattr(sys, "frozen", False) else os.path.abspath(__file__))
    appdata = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "Player64X", "models")
    dirs = [os.path.join(base_dir(), "models"), os.path.join(exe_dir, "models"), appdata]
    return [d for d in dict.fromkeys(dirs) if os.path.isdir(d)]


def _probe(py):
    """py 가 CUDA PyTorch 를 쓸 수 있으면 True"""
    try:
        r = subprocess.run([py, "-c", "import torch,sys;sys.exit(0 if torch.cuda.is_available() else 1)"],
                           capture_output=True, timeout=90, creationflags=CREATE_NO_WINDOW)
        return r.returncode == 0
    except Exception:
        return False


def find_ai_python():
    """CUDA PyTorch 가 설치된 python 을 찾는다 (한 번 찾으면 AppData 에 기억)."""
    cache = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "Player64X", "ai_python.txt")
    cands = []
    if os.environ.get("PLAYER64X_AI_PYTHON"):
        cands.append(os.environ["PLAYER64X_AI_PYTHON"])
    try:
        with open(cache, "r", encoding="utf-8") as f:
            cands.append(f.read().strip())
    except OSError:
        pass
    home = os.path.expanduser("~")
    roots = [os.path.join(home, "Desktop"), os.path.join(home, "Documents"), home, "C:\\", "D:\\"]
    for root in roots:
        try:
            subs = [os.path.join(root, n) for n in os.listdir(root)]
        except OSError:
            continue
        for s in subs:
            for rel in (r"venv\Scripts\python.exe", r".venv\Scripts\python.exe", r"python_embeded\python.exe"):
                p = os.path.join(s, rel)
                if os.path.isfile(p):
                    cands.append(p)
    cands.append("python")
    for p in dict.fromkeys(c for c in cands if c):
        if (os.path.isfile(p) or p == "python") and _probe(p):
            try:
                os.makedirs(os.path.dirname(cache), exist_ok=True)
                with open(cache, "w", encoding="utf-8") as f:
                    f.write(p)
            except OSError:
                pass
            return p
    return None


def pictures_dir():
    d = os.path.join(QStandardPaths.writableLocation(QStandardPaths.PicturesLocation), "Player64X")
    os.makedirs(d, exist_ok=True)
    return d


class AiEngine(QObject):
    stateChanged = Signal()
    flowChanged = Signal(bool)      # AI 프레임이 흐르는 중인가 (화면에 AI 영상 표시 여부)
    captureDone = Signal(str)       # AI 캡처 결과 메시지
    _frameReady = Signal(object)    # 작업 스레드 -> GUI 스레드

    def __init__(self):
        super().__init__()
        self._status = "AI 꺼짐"
        self._rt = False
        self._model = 0
        self._src = None
        self._out = None
        self._ready = False
        self._thread = None
        self._proc = None
        self._stop = False
        self._cv = threading.Condition()
        self._rt_job = None
        self._rt_pending = False
        self._caps = []
        self._warned_big = False
        self._fps_n = 0
        self._fps_t = time.time()
        self._gpu = ""
        self._flow_timer = QTimer(self)
        self._flow_timer.setSingleShot(True)
        self._flow_timer.setInterval(500)
        self._flow_timer.timeout.connect(lambda: self.flowChanged.emit(False))
        self._frameReady.connect(self._show)

    # ---------- 상태 문자열 ----------
    def _set_status(self, text):
        if text != self._status:
            self._status = text
            self.stateChanged.emit()

    @Property(str, notify=stateChanged)
    def status(self):
        return self._status

    # ---------- 실시간 ----------
    @Slot(bool, int, QVideoSink, QVideoSink)
    def setRealtime(self, on, model, src, out):
        """on: 실시간 AI 켜기/끄기, model: 0 실사 1 애니, src: 원본 프레임, out: AI 프레임을 그릴 곳"""
        if self._src is not None and self._src is not src:
            try:
                self._src.videoFrameChanged.disconnect(self._on_frame)
            except (RuntimeError, TypeError):
                pass
        self._model = model
        self._out = out
        if on:
            if self._src is not src:
                src.videoFrameChanged.connect(self._on_frame)
            self._src = src
            self._rt = True
            self._warned_big = False
            self._ensure_started()
            self._set_status("AI 엔진 시작 중…" if not self._ready else f"실시간 AI 대기 중 · {self._gpu}")
        else:
            self._rt = False
            with self._cv:
                self._rt_job = None
                self._rt_pending = False
            self.flowChanged.emit(False)
            self._set_status("AI 꺼짐" if not self._ready else f"AI 엔진 준비됨 · {self._gpu}")

    @Slot(int)
    def setModel(self, model):
        self._model = model

    def _on_frame(self, frame):
        if not self._rt or not self._ready or self._rt_pending or not frame.isValid():
            return
        img = frame.toImage()
        if img.isNull():
            return
        w, h = img.width(), img.height()
        if w * h > RT_MAX_PIXELS:
            if not self._warned_big:
                self._warned_big = True
                self.flowChanged.emit(False)
                self._set_status(f"이 영상({w}x{h})은 실시간 AI 에는 큽니다 · 'AI 캡처' 또는 GPU 선명화를 쓰세요")
            return
        img = img.convertToFormat(QImage.Format_RGBX8888)
        scale = 4 if max(w, h) * 4 <= RT_MAX_SIDE else 2
        data = bytes(img.constBits())
        with self._cv:
            self._rt_pending = True
            self._rt_job = ("rt", data, w, h, scale, self._model, None)
            self._cv.notify()

    def _show(self, img):
        if not self._rt or self._out is None:
            return
        self._out.setVideoFrame(QVideoFrame(img))
        self.flowChanged.emit(True)
        self._flow_timer.start()
        self._fps_n += 1
        now = time.time()
        if now - self._fps_t >= 1.0:
            fps = self._fps_n / (now - self._fps_t)
            self._fps_n, self._fps_t = 0, now
            self._set_status(f"실시간 AI 작동 중 · {fps:.0f}fps · {MODEL_NAMES.get(self._model, '')} · "
                             f"{img.width()}x{img.height()} 출력")

    # ---------- AI 캡처 ----------
    @Slot(QVideoSink, str, int, int)
    def capture(self, src, name, ms, model):
        frame = src.videoFrame()
        if not frame.isValid():
            self.captureDone.emit("캡처할 장면이 없습니다")
            return
        img = frame.toImage()
        if img.isNull():
            self.captureDone.emit("프레임을 읽지 못했습니다")
            return
        w, h = img.width(), img.height()
        long_side = max(w, h)
        scale = 4 if long_side * 4 <= CAP_MAX_SIDE else 2 if long_side * 2 <= CAP_MAX_SIDE else 1
        if scale == 1:
            self.captureDone.emit(f"이미 해상도가 매우 높습니다({w}x{h}) · 일반 캡처(C)를 쓰세요")
            return
        img = img.convertToFormat(QImage.Format_RGBX8888)
        data = bytes(img.constBits())
        stem = re.sub(r'[\\/:*?"<>|]', "_", os.path.splitext(name)[0]) or "capture"
        t = f"{ms // 3600000:02d}-{ms // 60000 % 60:02d}-{ms // 1000 % 60:02d}-{ms % 1000:03d}"
        meta = (stem, t, scale)
        with self._cv:
            self._caps.append(("cap", data, w, h, scale, model, meta))
            self._cv.notify()
        self._ensure_started()
        self._set_status(f"AI 캡처 처리 중… ({w}x{h} → {w * scale}x{h * scale})")

    # ---------- 작업 스레드 ----------
    def _ensure_started(self):
        if self._thread and self._thread.is_alive():
            return
        self._stop = False
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _read(self, n):
        buf = bytearray()
        while len(buf) < n:
            chunk = self._proc.stdout.read(n - len(buf))
            if not chunk:
                raise EOFError("AI 작업 프로세스가 종료되었습니다")
            buf += chunk
        return bytes(buf)

    def _run(self):
        try:
            py = find_ai_python()
            if not py:
                self._set_status("AI 엔진을 쓸 수 없습니다 · CUDA 가 되는 PyTorch 설치가 필요합니다")
                self.captureDone.emit("AI 엔진을 찾을 수 없습니다 (CUDA PyTorch 필요)")
                return
            env = dict(os.environ, PLAYER64X_MODELS=os.pathsep.join(model_dirs()), PYTHONIOENCODING="utf-8")
            log = open(os.path.join(os.environ.get("TEMP", "."), "player64x_ai.log"), "wb")
            self._proc = subprocess.Popen(
                [py, os.path.join(base_dir(), "ai_worker.py")], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                stderr=log, env=env, creationflags=CREATE_NO_WINDOW)
            h = HDR.unpack(self._read(HDR.size))
            self._gpu = self._read(h[5]).decode("utf-8", "replace")
            self._ready = True
            self._set_status(f"실시간 AI 대기 중 · {self._gpu}" if self._rt else f"AI 엔진 준비됨 · {self._gpu}")

            while not self._stop:
                with self._cv:
                    while not self._stop and not self._caps and not (self._rt_job and self._rt):
                        self._cv.wait(0.5)
                    if self._stop:
                        break
                    job = self._caps.pop(0) if self._caps else self._rt_job
                    if job[0] == "rt":
                        self._rt_job = None
                kind, data, w, hh, scale, model, meta = job
                self._proc.stdin.write(HDR.pack(b"REQ0", model, scale, 0, 0, w, hh) + data)
                self._proc.stdin.flush()
                r = HDR.unpack(self._read(HDR.size))
                if r[1] != 0:
                    msg = self._read(r[5]).decode("utf-8", "replace")
                    self._set_status("AI 오류 · " + msg)
                    if kind == "cap":
                        self.captureDone.emit("AI 캡처 실패 · " + msg)
                    self._rt_pending = False
                    continue
                w2, h2 = r[5], r[6]
                pix = self._read(w2 * h2 * 4)
                img = QImage(pix, w2, h2, w2 * 4, QImage.Format_RGBX8888).copy()
                if kind == "rt":
                    self._rt_pending = False
                    self._frameReady.emit(img)
                else:
                    stem, t, sc = meta
                    path = os.path.join(pictures_dir(), f"{stem}_{t}_AI{sc}x.png")
                    n = 2
                    while os.path.exists(path):
                        path = os.path.join(pictures_dir(), f"{stem}_{t}_AI{sc}x_{n}.png")
                        n += 1
                    ok = img.save(path, "PNG", 80)
                    self.captureDone.emit(f"AI 캡처 저장됨 · {w}x{hh} → {w2}x{h2} · 사진\\Player64X\\{os.path.basename(path)}"
                                          if ok else "AI 캡처 저장에 실패했습니다")
                    self._set_status(f"실시간 AI 대기 중 · {self._gpu}" if self._rt else f"AI 엔진 준비됨 · {self._gpu}")
        except Exception as e:
            self._set_status(f"AI 엔진 오류 · {e}")
            self.captureDone.emit(f"AI 엔진 오류 · {e}")
        finally:
            self._ready = False
            self._rt_pending = False
            try:
                if self._proc and self._proc.poll() is None:
                    self._proc.kill()
            except Exception:
                pass

    @Slot()
    def shutdown(self):
        self._stop = True
        with self._cv:
            self._cv.notify_all()
        try:
            if self._proc and self._proc.poll() is None:
                self._proc.stdin.close()
                self._proc.kill()
        except Exception:
            pass
