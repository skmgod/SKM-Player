"""AI 화질개선 작업 프로세스 (CUDA PyTorch 가 있는 python 으로 실행됨).

플레이어(ai_engine.py)와 stdin/stdout 이진 프로토콜로 통신한다.
  요청 : '<4sBBBBII'  magic=b'REQ0', model, scale, mode, pad, W, H  + RGBA 바이트(W*H*4)
  응답 : '<4sBBBBII'  magic=b'RESP', status(0 ok/1 error), 0, 0, 0, W2, H2 + RGBX 바이트  (error 이면 W2=메시지 길이, 뒤에 UTF-8 메시지)
모델: Real-ESRGAN compact (SRVGGNetCompact) x4 — BSD-3-Clause, https://github.com/xinntao/Real-ESRGAN
"""
import os
import struct
import sys

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

HDR = struct.Struct("<4sBBBBII")
MODELS = {0: ("realesr-general-x4v3.pth", 32), 1: ("realesr-animevideov3.pth", 16)}
TILE_PIXELS = 1_200_000     # 이보다 큰 입력은 타일로 나눠 처리 (VRAM 보호)


class SRVGGNetCompact(nn.Module):
    def __init__(self, num_feat=64, num_conv=16, upscale=4):
        super().__init__()
        self.upscale = upscale
        body = [nn.Conv2d(3, num_feat, 3, 1, 1), nn.PReLU(num_parameters=num_feat)]
        for _ in range(num_conv):
            body += [nn.Conv2d(num_feat, num_feat, 3, 1, 1), nn.PReLU(num_parameters=num_feat)]
        body.append(nn.Conv2d(num_feat, 3 * upscale * upscale, 3, 1, 1))
        self.body = nn.ModuleList(body)
        self.up = nn.PixelShuffle(upscale)

    def forward(self, x):
        out = x
        for layer in self.body:
            out = layer(out)
        out = self.up(out)
        return out + F.interpolate(x, scale_factor=self.upscale, mode="nearest")


def read_exact(stream, n):
    buf = bytearray()
    while len(buf) < n:
        chunk = stream.read(n - len(buf))
        if not chunk:
            raise EOFError
        buf += chunk
    return bytes(buf)


def model_dirs():
    d = os.environ.get("PLAYER64X_MODELS", "")
    return [p for p in d.split(os.pathsep) if p]


_cache = {}


def get_model(mid):
    if mid in _cache:
        return _cache[mid]
    fname, nconv = MODELS[mid]
    path = next((os.path.join(d, fname) for d in model_dirs() if os.path.isfile(os.path.join(d, fname))), None)
    if path is None:
        raise FileNotFoundError(f"모델 파일이 없습니다: {fname}  (models 폴더에 넣어 주세요)")
    state = torch.load(path, map_location="cpu", weights_only=True)
    state = state.get("params", state)
    m = SRVGGNetCompact(num_conv=nconv)
    m.load_state_dict(state, strict=True)
    m = m.half().cuda().eval().to(memory_format=torch.channels_last)
    with torch.inference_mode():          # 워밍업
        m(torch.zeros(1, 3, 64, 64, device="cuda", dtype=torch.half).to(memory_format=torch.channels_last))
    _cache[mid] = m
    return m


@torch.inference_mode()
def enhance(m, rgba, w, h, scale):
    a = np.frombuffer(rgba, dtype=np.uint8).reshape(h, w, 4)[:, :, :3]
    x = torch.from_numpy(np.ascontiguousarray(a)).cuda(non_blocking=True)
    x = x.permute(2, 0, 1).unsqueeze(0).half().div_(255).contiguous(memory_format=torch.channels_last)

    if w * h <= TILE_PIXELS:
        out = m(x)
    else:                                   # 타일 처리
        tile, pad, s = 256, 16, 4
        out = torch.empty((1, 3, h * s, w * s), dtype=x.dtype, device=x.device)
        for y in range(0, h, tile):
            for xx in range(0, w, tile):
                y0, y1 = max(y - pad, 0), min(y + tile + pad, h)
                x0, x1 = max(xx - pad, 0), min(xx + tile + pad, w)
                o = m(x[:, :, y0:y1, x0:x1])
                th, tw = min(tile, h - y), min(tile, w - xx)
                oy, ox = (y - y0) * s, (xx - x0) * s
                out[:, :, y * s:(y + th) * s, xx * s:(xx + tw) * s] = o[:, :, oy:oy + th * s, ox:ox + tw * s]

    if scale != 4:
        size = (h * scale, w * scale)
        try:
            out = F.interpolate(out, size=size, mode="bicubic", antialias=True, align_corners=False)
        except RuntimeError:
            out = F.interpolate(out.float(), size=size, mode="bicubic", antialias=True, align_corners=False)

    out = out.clamp_(0, 1).mul_(255).round_().to(torch.uint8)[0].permute(1, 2, 0)
    alpha = torch.full((*out.shape[:2], 1), 255, dtype=torch.uint8, device=out.device)
    out = torch.cat([out, alpha], dim=2).contiguous()
    return out.cpu().numpy().tobytes(), out.shape[1], out.shape[0]


def main():
    inp, outp = sys.stdin.buffer, sys.stdout.buffer
    torch.backends.cudnn.benchmark = True
    name = torch.cuda.get_device_name(0).encode("utf-8")
    outp.write(HDR.pack(b"HELO", 0, 0, 0, 0, len(name), 0) + name)
    outp.flush()
    while True:
        try:
            magic, mid, scale, mode, _, w, h = HDR.unpack(read_exact(inp, HDR.size))
            rgba = read_exact(inp, w * h * 4)
        except EOFError:
            return
        try:
            data, w2, h2 = enhance(get_model(mid), rgba, w, h, scale)
            outp.write(HDR.pack(b"RESP", 0, 0, 0, 0, w2, h2) + data)
        except Exception as e:   # 오류는 플레이어에 알려 주고 계속 동작
            torch.cuda.empty_cache()
            msg = f"{type(e).__name__}: {e}".encode("utf-8")
            outp.write(HDR.pack(b"RESP", 1, 0, 0, 0, len(msg), 0) + msg)
        outp.flush()


if __name__ == "__main__":
    main()
