"""Capture a web page or one application window to a PNG file.

--url renders the page in headless Chromium through the Playwright CLI.
--window captures a top-level Windows window, matched by process name or by a
substring of its title. Screen copies the window's on-screen pixels after
bringing it forward, which works for games; Print asks the window to render
itself, which works while it is covered but can return black for DirectX or
OpenGL surfaces.
"""

from __future__ import annotations

import argparse
import ctypes
import shutil
import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path


DIB_RGB_COLORS = 0
SRCCOPY = 0x00CC0020
CAPTUREBLT = 0x40000000
DWMWA_EXTENDED_FRAME_BOUNDS = 9
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
SW_RESTORE = 9


class Rect(ctypes.Structure):
    _fields_ = [("left", ctypes.c_long), ("top", ctypes.c_long), ("right", ctypes.c_long), ("bottom", ctypes.c_long)]


class BitmapInfoHeader(ctypes.Structure):
    _fields_ = [
        ("biSize", ctypes.c_uint32),
        ("biWidth", ctypes.c_long),
        ("biHeight", ctypes.c_long),
        ("biPlanes", ctypes.c_uint16),
        ("biBitCount", ctypes.c_uint16),
        ("biCompression", ctypes.c_uint32),
        ("biSizeImage", ctypes.c_uint32),
        ("biXPelsPerMeter", ctypes.c_long),
        ("biYPelsPerMeter", ctypes.c_long),
        ("biClrUsed", ctypes.c_uint32),
        ("biClrImportant", ctypes.c_uint32),
    ]


class BitmapInfo(ctypes.Structure):
    _fields_ = [("bmiHeader", BitmapInfoHeader), ("bmiColors", ctypes.c_uint32 * 3)]


class Window:
    def __init__(self, handle: int, process: str, title: str) -> None:
        self.handle = handle
        self.process = process
        self.title = title


def win32() -> tuple:
    """Load the DLLs with 64-bit-safe prototypes; Windows only."""
    user32 = ctypes.WinDLL("user32")
    gdi32 = ctypes.WinDLL("gdi32")
    dwmapi = ctypes.WinDLL("dwmapi")
    kernel32 = ctypes.WinDLL("kernel32")
    user32.GetDC.restype = ctypes.c_void_p
    user32.GetDC.argtypes = [ctypes.c_void_p]
    user32.ReleaseDC.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    user32.EnumWindows.argtypes = [ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p), ctypes.c_void_p]
    user32.IsWindowVisible.argtypes = [ctypes.c_void_p]
    user32.GetWindowTextLengthW.argtypes = [ctypes.c_void_p]
    user32.GetWindowTextW.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_int]
    user32.GetWindowThreadProcessId.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong)]
    user32.IsIconic.argtypes = [ctypes.c_void_p]
    user32.ShowWindow.argtypes = [ctypes.c_void_p, ctypes.c_int]
    user32.SetForegroundWindow.argtypes = [ctypes.c_void_p]
    user32.PrintWindow.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint]
    gdi32.CreateCompatibleDC.restype = ctypes.c_void_p
    gdi32.CreateCompatibleDC.argtypes = [ctypes.c_void_p]
    gdi32.CreateCompatibleBitmap.restype = ctypes.c_void_p
    gdi32.CreateCompatibleBitmap.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
    gdi32.SelectObject.restype = ctypes.c_void_p
    gdi32.SelectObject.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
    gdi32.DeleteObject.argtypes = [ctypes.c_void_p]
    gdi32.DeleteDC.argtypes = [ctypes.c_void_p]
    gdi32.BitBlt.argtypes = [
        ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int,
        ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_uint32,
    ]
    gdi32.GetDIBits.argtypes = [
        ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32, ctypes.c_uint32,
        ctypes.c_void_p, ctypes.POINTER(BitmapInfo), ctypes.c_uint32,
    ]
    dwmapi.DwmGetWindowAttribute.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_void_p, ctypes.c_uint32]
    kernel32.OpenProcess.restype = ctypes.c_void_p
    kernel32.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
    kernel32.QueryFullProcessImageNameW.argtypes = [
        ctypes.c_void_p, ctypes.c_uint32, ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_ulong),
    ]
    kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    return user32, gdi32, dwmapi, kernel32


def capture_url(url: str, out_file: Path, width: int, height: int, full_page: bool) -> None:
    npx = shutil.which("npx")
    if not npx:
        raise RuntimeError("npx was not found. Install Node.js 18 or later (https://nodejs.org), then rerun.")
    arguments = [
        "--yes",
        "playwright",
        "screenshot",
        "--browser",
        "chromium",
        f"--viewport-size={width},{height}",
        "--wait-for-timeout",
        "1000",
    ]
    if full_page:
        arguments.append("--full-page")
    result = subprocess.run([npx, *arguments, url, str(out_file)], check=False)
    if result.returncode:
        raise RuntimeError("Playwright failed. If the browser is missing, run: npx --yes playwright install chromium")


def native_window_command() -> str:
    if sys.platform == "darwin":
        return "screencapture -w <file>.png for a click-selected window"
    return "gnome-screenshot -w, or import -window <window-id> <file>.png (ImageMagick)"


def process_name(kernel32: object, pid: int) -> str:
    handle = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not handle:
        return ""
    try:
        size = ctypes.c_ulong(32768)
        buffer = ctypes.create_unicode_buffer(size.value)
        if not kernel32.QueryFullProcessImageNameW(handle, 0, buffer, ctypes.byref(size)):
            return ""
        return Path(buffer.value).stem
    finally:
        kernel32.CloseHandle(handle)


def visible_windows(user32: object, kernel32: object) -> list[Window]:
    # Get-Process reports one main window per process: the first visible top-level window in Z-order.
    found: dict[int, Window] = {}
    order: list[int] = []

    def collect(handle: int, _: int) -> bool:
        if not user32.IsWindowVisible(handle):
            return True
        length = user32.GetWindowTextLengthW(handle)
        if length <= 0:
            return True
        title = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(handle, title, length + 1)
        pid = ctypes.c_ulong()
        user32.GetWindowThreadProcessId(handle, ctypes.byref(pid))
        if pid.value not in found:
            found[pid.value] = Window(handle, process_name(kernel32, pid.value), title.value)
            order.append(pid.value)
        return True

    callback = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_void_p, ctypes.c_void_p)(collect)
    user32.EnumWindows(callback, 0)
    return [found[pid] for pid in order]


def select_window(user32: object, kernel32: object, name: str) -> Window:
    windows = visible_windows(user32, kernel32)
    # An exact process name is the more deliberate match, so it wins over title substrings.
    candidates = [window for window in windows if window.process.lower() == name.lower()]
    if not candidates:
        candidates = [window for window in windows if name.lower() in window.title.lower()]
    if not candidates:
        raise RuntimeError(f"No visible window matches '{name}'. Start the application first.")
    if len(candidates) > 1:
        names = "; ".join(f"{window.process}: {window.title}" for window in candidates)
        raise RuntimeError(f"Several windows match '{name}': {names}. Pass a more specific title.")
    return candidates[0]


def write_png(path: Path, width: int, height: int, pixels: bytes) -> None:
    rows = bytearray()
    for top in range(height):
        source = pixels[top * width * 4 : (top + 1) * width * 4]
        rgb = bytearray(width * 3)
        rgb[0::3] = source[2::4]
        rgb[1::3] = source[1::4]
        rgb[2::3] = source[0::4]
        rows += b"\x00" + rgb

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", header)
        + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
        + chunk(b"IEND", b"")
    )


def capture_window(name: str, out_file: Path, method: str) -> None:
    user32, gdi32, dwmapi, kernel32 = win32()
    # Physical pixels: without this, a scaled display reports logical coordinates and the capture is cropped.
    user32.SetProcessDPIAware()

    window = select_window(user32, kernel32, name)
    if user32.IsIconic(window.handle):
        user32.ShowWindow(window.handle, SW_RESTORE)
        time.sleep(0.3)

    # The extended frame bounds exclude the invisible resize border that GetWindowRect includes.
    rect = Rect()
    dwmapi.DwmGetWindowAttribute(window.handle, DWMWA_EXTENDED_FRAME_BOUNDS, ctypes.byref(rect), ctypes.sizeof(rect))
    width = rect.right - rect.left
    height = rect.bottom - rect.top
    if width <= 0 or height <= 0:
        raise RuntimeError(f"Window '{name}' has no visible area.")

    screen = user32.GetDC(None)
    memory = gdi32.CreateCompatibleDC(screen)
    bitmap = gdi32.CreateCompatibleBitmap(screen, width, height)
    selected = gdi32.SelectObject(memory, bitmap)
    try:
        if method == "Screen":
            user32.SetForegroundWindow(window.handle)
            time.sleep(0.4)
            gdi32.BitBlt(memory, 0, 0, width, height, screen, rect.left, rect.top, SRCCOPY | CAPTUREBLT)
        else:
            # 2 = PW_RENDERFULLCONTENT, needed for windows composed by DirectComposition.
            if not user32.PrintWindow(window.handle, memory, 2):
                raise RuntimeError("PrintWindow failed. Retry with --method Screen.")
        info = BitmapInfo()
        info.bmiHeader.biSize = ctypes.sizeof(BitmapInfoHeader)
        info.bmiHeader.biWidth = width
        info.bmiHeader.biHeight = -height
        info.bmiHeader.biPlanes = 1
        info.bmiHeader.biBitCount = 32
        info.bmiHeader.biCompression = 0
        buffer = ctypes.create_string_buffer(width * height * 4)
        if not gdi32.GetDIBits(memory, bitmap, 0, height, buffer, ctypes.byref(info), DIB_RGB_COLORS):
            raise RuntimeError(f"Could not read the pixels of window '{name}'.")
        write_png(out_file, width, height, buffer.raw)
    finally:
        gdi32.SelectObject(memory, selected)
        gdi32.DeleteObject(bitmap)
        gdi32.DeleteDC(memory)
        user32.ReleaseDC(None, screen)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--url", "-Url")
    source.add_argument("--window", "-Window")
    parser.add_argument("--out-file", "-OutFile", required=True, type=Path)
    parser.add_argument("--width", "-Width", type=int)
    parser.add_argument("--height", "-Height", type=int)
    parser.add_argument("--full-page", "-FullPage", action="store_true")
    parser.add_argument("--method", "-Method", choices=("Screen", "Print"))
    args = parser.parse_args()
    if args.window:
        page_options = [
            flag
            for flag, given in (("--width", args.width), ("--height", args.height), ("--full-page", args.full_page))
            if given
        ]
        if page_options:
            parser.error(f"{', '.join(page_options)} belongs to --url, not --window.")
    elif args.method:
        parser.error("--method belongs to --window, not --url.")

    out_file = args.out_file.resolve()
    out_file.parent.mkdir(parents=True, exist_ok=True)
    try:
        if args.url:
            capture_url(
                args.url,
                out_file,
                args.width if args.width is not None else 1280,
                args.height if args.height is not None else 720,
                args.full_page,
            )
        else:
            if sys.platform != "win32":
                raise RuntimeError(f"Window capture is implemented for Windows only. Use: {native_window_command()}")
            capture_window(args.window, out_file, args.method if args.method else "Screen")
    except RuntimeError as error:
        print(error, file=sys.stderr)
        return 1

    size = round(out_file.stat().st_size / 1024)
    print(f"Saved {out_file} ({size} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
