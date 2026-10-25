# Download and run the FPV prototype

No VS Code, Godot installation, controller, or account is needed to run the Windows prototype.

1. Open `FPVTrainer-Windows-Prototype.zip` in this GitHub folder.
2. Click **Download raw file** (the download arrow). GitHub cannot preview ZIP files.
3. Find the ZIP in Downloads, right-click it, and choose **Extract All**.
4. Open the extracted FPVTrainer folder and run **FPVTrainer.exe**. Keep all four files together.
5. Press Enter to start. Tap Up arrow gradually for power. W/S tilt forward/back, A/D roll, Q/E turn. Down arrow reduces power. R restarts; Enter pauses.

Keyboard throttle stays at the level you set. Releasing the keys does not self-level the drone. Small inputs help.

This is an initial, unsigned Windows x86-64 prototype, exported in Linux. Windows operation, frame rate and physical radios have not yet been tested. Do not disable security software if a warning appears; report the exact warning for diagnosis.

The course uses rectangular placeholders for all 13 stations. Flight physics and impact detection are preliminary. No polished menu or graphical editor exists yet. See source/fpv-trainer/README.md for current limitations and development instructions.
