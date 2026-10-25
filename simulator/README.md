# DTC Flight Lab — offline FPV simulator v0.3

## Download for Windows

**[Download Windows ZIP (about 36 MB)](https://github.com/Usama2896/my.portfolio/raw/refs/heads/fpv-simulator-prototype/simulator/FPVTrainer-Windows-Prototype.zip)**

1. Download the ZIP above. No VS Code or controller is required.
2. In Downloads, right-click the ZIP → **Extract All** → **Extract**.
3. Open **FPVTrainer**, then run **FPVTrainer.exe**. Keep all files together.
4. Click **Start keyboard-friendly practice**. The drone automatically holds height.
5. Hold **↑** to climb; release to hold height. **↓** descends. Tap **W/S** to tilt forward/back, **A/D** roll, **Q/E** or **Left/Right arrows** turn in place.
6. **Enter** pauses, **R** restarts, **Esc** returns to the menu.

If Windows shows a security warning, do not disable protection; report the exact wording. This development build is unsigned and has not been run on Windows yet.

## What's new

- 17 selectable obstacle types. The supplied 13-station course uses rings, hexagons, five-pole zigzag, precision gate, triple ring, corridor, tunnel, U-tunnel and KZ. Extra options: triangle, square, diamond, arch, ladder, dive ring, hurdle and flag turn.
- Assisted keyboard practice and separate Acro assessments.
- Course editor with dimensions, add/remove/duplicate/reorder, draggable map, individual gaps, whole-course spacing, local save and JSON import/export.
- Drone/control settings, USB axis calibration/inversion/dead zone, and a shadow toggle for slower laptops.
- Pilot names, local training history, scoring and CSV results export.
- New menus, field, sky, vegetation, lighting, shadows, flight HUD, minimap and motor sound.

## Plain-English USB remote guide

**[Read REMOTE-SETUP.txt](REMOTE-SETUP.txt)** — step-by-step USB copying, RadioMaster connection, Windows controller check, stick mapping, calibration, first flight and troubleshooting. The same guide is inside the Windows ZIP and accessible in Drone & Controls.

Keyboard yaw: **Q / Left arrow = turn left (CCW); E / Right arrow = turn right (CW)**. A/D bank the drone. The FPV camera turns with the drone; there is no separate camera gimbal.

Spacing: in Course Editor select station 02 or later, set **Gap from previous (m)**, and Save. **Move later stations together** preserves later gaps. **Whole-course spacing ×** expands/contracts all station locations without resizing obstacles.

If a saved v0.2 course loads, export it first if you want a backup, then use **Restore supplied course** to see the updated default 8 m Zig Zag pole line.

## Actual screenshots

These are rendered from the application, not concept images.

![Home and course overview](screenshots/home.png)
![First-person flight](screenshots/flight.png)
![Course editor](screenshots/editor.png)
![Triple ring](screenshots/triple.png)
![Tunnel](screenshots/tunnel.png)

Extra types: [triangle](screenshots/triangle.png), [square](screenshots/square.png), [diamond](screenshots/diamond.png), [arch](screenshots/arch.png), [ladder](screenshots/ladder.png), [dive ring](screenshots/dive.png), [hurdle](screenshots/hurdle.png), [flag](screenshots/flag.png).

More views: [hexagon](screenshots/hexagon.png), [zigzag](screenshots/zigzag.png), [corridor](screenshots/corridor.png), [U-tunnel](screenshots/u-tunnel.png), [KZ](screenshots/kz.png), [controls](screenshots/controls.png), [results](screenshots/results.png).

## Tested versus pending

240 automated checks passed in Linux: 114 scene/shape/course/settings/rules/axis checks, 96 new obstacle/spacing checks, 24 full-turn yaw checks and 6 keyboard-flight checks. Q/E and Left/Right each turned the drone through 360° in both practice and assessment without unintended banking. Actual rendered views were inspected. Windows export and packed-resource startup were checked. Physical Windows operation, laptop frame rate and RadioMaster remotes still need testing.

This is a much more capable development release, not yet a finished Liftoff replacement. Layout/dimensions and some obstacle interpretations remain approximate. Physics, wind and crash classification are preliminary; bonus timing defaults to disabled pending the missing rule. See the [full guide and limitations](source/fpv-trainer/README.md).

Source project: [source/fpv-trainer](source/fpv-trainer). Your original portfolio files are unchanged.
