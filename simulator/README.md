# AL JEHAD FPV OBSTACLE COURSE — v0.10

[Download Windows ZIP](https://github.com/Usama2896/my.portfolio/raw/refs/heads/fpv-simulator-prototype/simulator/FPVTrainer-Windows-Prototype.zip)

Close the old app, extract the ZIP into a new folder, then open **AL-JEHAD-FPV/AlJehadFPV.exe**. Check **V0.10**. No Godot, VS Code, installer or Internet is required to run it. Existing calibration, saved courses and records are retained.

## New in v0.10 — civilian camera-drone missions

Open **Civilian Missions** (or the civilian button in Fly) and choose:

- **Parcel Delivery:** take off, fly to the square service pad, land and hold Down / fully low throttle to settle for two seconds. Press **U** or **Unload** to place a parcel on the ground, then take off and return to Home. Physical contact, low speed, a level drone and a complete landing inside the pad are required. There is no airborne release, projectile or impact-scoring path.
- **Landing Practice:** fly to a civilian pad and land. Review elapsed time, pad offset and descent feedback in Training Results. Practice feedback is separate from competitive FPV scoring.

Both events use an original offline woodland park, ordinary camera-drone visuals, road markings, configurable 20–200 m routes and 2–8 m square pads. Choose keyboard or an already supported USB radio. Gentle level controls are enabled; solo course and preferences return on leaving. **View** switches follow / forward / landing camera. The Skydroid G12's Windows joystick compatibility remains unconfirmed; no new hardware driver or release-switch integration is claimed.

**Esc** now opens Resume, Fullscreen/Windowed, Main menu and **Exit application ×**. Solo flight pauses; LAN flight and the shared clock continue. The window layout expands to wide screens, removing the old fixed-aspect side bars. F11 remains available. In relay, waiting/finished pilots automatically follow the active pilot's reconstructed FPV view. Auto / P1 / P2 / P3 / Mine buttons and 0/1/2/3 keys choose a read-only view; your own camera takes priority during your turn. This renders the shared 3D state locally, not a stream of another PC's desktop.

![Civilian missions](screenshots/civilian-menu.png)
![Woodland park flight](screenshots/civilian-flight.png)
![Escape and Exit menu](screenshots/escape-menu.png)
![Read-only relay camera](screenshots/spectator-p2.png)

Validation: 562 Godot checks, seven radio-page checks and one native mouse-launch check passed (570 total), plus four real ENet network scenarios. The new checks include airborne-unload rejection, actual ground contact, return landing, pause, saved feedback, spectator transitions and control priority. Rendered 16:9 views were checked. Physical Windows/radio/goggles verification remains necessary. This release adds no real-world map download, weapons exercise or aerial payload release.

## New: LAN Competition — v0.10

**[Three-PC beginner setup guide](LAN-SETUP.md)**

- **Team Relay:** exactly three pilots and three drones. SP → LZ1 → LZ2 → LZ3; a settled valid landing releases the next pilot. One PC hosts and also flies. Join order assigns pilots 2 and 3.
- **Obstacle Race:** two or three pilots race simultaneously through the host's edited course. Directional gate/section/lap progress is checked by the host; client courses are restored on leaving.
- **Mountain valley, Desert plain and City streets** relay environments. Three independent leg lengths, 30–5000 m each, including 1 km. Geometry count remains bounded for long courses.
- Host-configurable LZ diameter (default two feet), landing hold, QT, maximum time and scoring. Shared control level: Easy, Stabilized or Acro. Relay defaults to 100 completion + 100 landing bonus, ±1 for every full five seconds against QT.
- Host countdown/clock, waiting-turn and landing checks, crash/false-start/outside-zone/time/disconnect rules, shared pilot board, local match history and CSV export.
- Each PC uses its own saved keyboard/radio mapping and FPV/goggles video connection. Existing activation key and Secure Mode owner label are preserved.
- No Internet server, SQL server or extra game installation dependency. LAN play uses built-in ENet/UDP, default port 24567. Calm conditions and no battery limit apply during competition; solo settings return on disconnect.

![LAN room setup](screenshots/lan-lobby.png)
![Relay FPV view](screenshots/lan-relay-flight.png)
![Mountain valley](screenshots/lan-mountain.png)
![Desert plain](screenshots/lan-desert.png)
![City streets](screenshots/lan-city.png)

Local v0.9 verification: 524 Godot checks, seven radio-page checks and one native mouse launch check passed, plus real ENet relay, two-/three-player obstacle and disconnect integration scenarios.

This is a lightweight LAN competition prototype with one local pilot per PC, not single-PC split-screen. It does not implement drone-to-drone collisions, public matchmaking, host migration, in-progress reconnect or anti-cheat. Physical three-PC Windows/RadioMaster/Cobra tests are still needed. Three-process relay, two-/three-process obstacle racing and disconnect behaviour were tested over actual ENet loopback sockets in Linux.

## Owner settings and activation — v0.10

One-time per-PC/account activation, five-second splash, `god Mode` label and fullscreen startup. Ask the owner for the key. Existing calibration remains saved. [Step-by-step editing, online builds and technical explanation](EDITING-GUIDE.md). Edit `source/fpv-trainer/owner_settings.gd` and rebuild; saving source alone does not change an EXE. Public source means a hard-coded activation key is a casual-copy deterrent, not strong DRM.

## Calibration memory — v0.10

The same radio automatically restores its saved axis mapping, travel limits, centres and inversions. It reuses the last profile even when its USB device index or instance GUID changes, provided the radio name identifies one connected device. Exact device profiles take priority. Older matching profiles are imported without deleting calibration. With several identical radios, select the intended device and verify its live values; USB cannot reliably distinguish identical names without stable identifiers.

Open Controls only when you want to change calibration. Map an axis and confirm as before; cancelling unfinished mapping keeps the saved settings. Calibration belongs to the Windows account on that PC, not to the ZIP or USB stick. A different PC/account needs initial calibration. Low-throttle arming is still required each flight; this is not recalibration.

Nine new checks cover a fresh app instance, endpoints, centres, inversions, reconnect, repeated GUID/index changes and cancellation. Remote launch and customization regressions also pass.

## What changed

- Punjab-inspired flat farmland, crop plots, irrigation channel, broadleaf trees, farm buildings and warmer daylight. Lightweight procedural scenery, not photorealistic assets.
- A continuous ground track with edge lines and direction arrows through the ordered stations. It rebuilds with course edits and can be disabled. The track shows horizontal route; use the airborne guide for climb/vertical tunnel sections.
- **Normal, Hot, Cold, Windy and Storm** weather presets. Custom wind 0–8 m/s, direction, gust strength and scene brightness. Storm has darker lighting and light rain. Hot/cold are visual presets, not battery-temperature or thermal simulations. Easy cancels wind for learning; assessment keeps calm competition conditions.
- A **six-minute battery** by default, adjustable from 0.5–30 minutes or disabled. Counts active motor-enabled flying from launch, even before the first gate. Pause and remote arming do not drain it. Warning beeps in the last 30 seconds; at zero, motors and flight assistance cut, the drone falls, and the flight ends on landing or after eight seconds. God Mode does not bypass battery. R starts a fresh flight and battery; checkpoint recovery does not recharge it. This is a time-limit model, not a voltage/current simulation.
- Difficulty selector ordered **Easy — Basic Guided**, **Medium — Beginner Stabilized**, **Hard — Acro Practice**, then **Acro Assessment**. Hard selects Acro for keyboard and radio. Experts can still customize keyboard assistance in controls.
- Optional **moving attitude reference in every level**. Press **V** to show/hide. It banks and moves with pitch relative to the fixed aiming reference. At level flight it returns to centre. This is separate from the fixed white diamond and the Basic opening target.
- Motor, impact, launch, gate-clear, finish and low-battery sound effects in all difficulty levels. One Sound effects switch controls them.
- Optional contact vibration requests for supported USB gamepads. Most RadioMaster USB joystick modes do not expose rumble; software cannot add that hardware capability.
- Goggles fullscreen output option and external-display selector. Windows Duplicate output is the simplest setup. This is a single FPV image, not stereo VR, device pairing or wireless video transmission.

![Ground route and battery](screenshots/pro-ground-route.png)
![Moving attitude reference](screenshots/pro-attitude.png)
![Storm preset](screenshots/pro-storm.png)

## First flight

1. Open **Fly** and choose **Easy — Basic Guided**. Leave God Mode on for initial practice.
2. Click **Fly with Keyboard**. W/S forward/back; A/D sideways; Q/E or Left/Right turns; Up/Down changes height. Release movement keys to stop.
3. Follow the ground arrows and cyan airborne guide. Align the centre diamond with the coloured opening target. The guide is visual, not autopilot.
4. **V** toggles the moving attitude line. Enter pauses, R restarts with a fresh battery, Esc opens menu, F11 toggles fullscreen.
5. For a radio, use **Fly with Remote**, lower throttle fully to arm, then raise above halfway to climb. Near halfway holds height in Easy/Medium; fully low cuts motors. Use your calibrated mapping.
6. Open **Drone & Controls**, scroll to **Environment & Flight Options**, and adjust weather, wind, battery, ground route, attitude, rumble and goggles options.

[Remote guide](REMOTE-SETUP.txt) · [Goggles connection guide](GOGGLES-SETUP.txt)

Cobra model inputs must be checked in its manual. AV-only goggles generally require a powered **active HDMI-to-composite converter** and the correct AV cable. USB may only provide power/firmware. No physical Cobra output or controller vibration has been verified in the cloud.

## Retained features

Faster adjustable yaw; upward-exit photo-based U-tunnel; real collision feedback and checkpoint recovery; God Mode; 17 obstacle shapes; individual zigzag pole positions; drone sizes; XYZ/rotation/spacing editor; JSON import/export; visibility/FOV controls; local sessions/CSV; USB mapping, calibration and diagnostics. Records remain in the existing DTC Flight Lab user-data directory.

## Earlier single-player validation

The v0.8 release passed 471 checks: 463 Godot checks plus seven offline radio-page checks and one native mouse launch check. These include 20 new environment, battery, route, difficulty and attitude checks plus 443 existing checks. The new tests verify battery cutoff in God Mode, pause, recharge, wind direction, setting persistence, collision-free ground route, mode order and the attitude line's bank/pitch direction. Rendered route, tilt and storm screens were inspected. Windows export is checked separately; a physical Windows/Cobra/TX16 test remains necessary.

[Development guide](source/fpv-trainer/README.md)
