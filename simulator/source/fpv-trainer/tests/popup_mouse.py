"""Run with DISPLAY set to an X11/Xvfb display; uses native XTest clicks."""
import ctypes
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

project = Path(__file__).resolve().parents[1]
coordinates = Path('/tmp/al-jehad-popup-mouse.json')
coordinates.unlink(missing_ok=True)
with tempfile.TemporaryDirectory(prefix='al-jehad-gui-') as data:
    environment = dict(os.environ, XDG_DATA_HOME=data)
    process = subprocess.Popen(['godot', '--audio-driver', 'Dummy', '--path', str(project),
                                '--script', 'res://tests/popup_mouse.gd'], env=environment)
    try:
        deadline = time.monotonic() + 55
        while not coordinates.exists():
            if process.poll() is not None:
                raise RuntimeError('Fixture exited before popup was ready')
            if time.monotonic() > deadline:
                raise TimeoutError('Popup rendering timed out')
            time.sleep(0.1)
        point = json.loads(coordinates.read_text())
        assert not point['disabled'], 'Start unexpectedly disabled after mapping correction'
        x11, xtest = ctypes.CDLL('libX11.so.6'), ctypes.CDLL('libXtst.so.6')
        x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
        x11.XOpenDisplay.restype = ctypes.c_void_p
        display = x11.XOpenDisplay(os.environ['DISPLAY'].encode())
        assert display, 'Cannot open X11 display'
        xtest.XTestFakeMotionEvent.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ulong]
        xtest.XTestFakeButtonEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
        x11.XFlush.argtypes = [ctypes.c_void_p]
        x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
        xtest.XTestFakeMotionEvent(display, -1, round(point['x']), round(point['y']), 0)
        xtest.XTestFakeButtonEvent(display, 1, 1, 0)
        xtest.XTestFakeButtonEvent(display, 1, 0, 0)
        x11.XFlush(display)
        result = process.wait(timeout=35)
        x11.XCloseDisplay(display)
        assert result == 0, f'Popup click test exited {result}'
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
