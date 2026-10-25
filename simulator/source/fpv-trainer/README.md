# DTC Flight Lab 0.3

An independent offline FPV course simulator built with Godot 4.6.3, using its lightweight Compatibility renderer. No Liftoff, Steam, account, network connection, VS Code or Godot installation is required on the Windows machine running the export.

## Four modules

1. **Fly** — assisted keyboard practice and separate Acro assessment, pilot name, FPV camera, target indicator, minimap, speed/height/power/lap telemetry and generated motor audio.
2. **Course Editor** — 17 procedural obstacle types; select, add, duplicate, remove and reorder stations; edit dimensions, location, heading and depth; drag map markers; adjust individual station gaps or overall spacing; save locally; import/export course JSON; adjust laps, qualifying/cutoff times and bonus interval.
3. **Drone & Controls** — camera FOV, mass, Acro rates, practice wind, keyboard assistance, motor sound, shadow toggle, USB axis assignment, endpoint/centre calibration, inversion, dead zone and device-specific saved mappings.
4. **Training Results** — local pilot/session history and CSV export for records or USB transfer. Shows the latest 30 sessions; export includes all saved sessions.

## First flight: no controller needed

1. Extract the Windows ZIP with **Extract All**.
2. Open the FPVTrainer folder and double-click **FPVTrainer.exe**. Keep all supplied files together.
3. Click **Start keyboard-friendly practice**.
4. The drone holds its starting height automatically. Hold **Up arrow** to climb; release it to hold height. Hold **Down arrow** to descend.
5. Briefly press **W** to tilt and move forward. Release to level; momentum slows gradually. **S** tilts back. **A/D** roll left/right. **Q/E** or **Left/Right arrows** turn left/right in place. **A/D bank; they do not turn the heading directly.**
6. Follow the highlighted target and the minimap. Cross gates in order, from their front. Tunnels and zigzag stations require passage through all their sections.
7. **Enter** pauses/resumes, **R** starts a fresh attempt, **Esc** returns to the menu. Clicking a top navigation button also stops the current flight.

In Acro assessment, Up/Down change motor power and the power stays at the value set. Releasing movement keys does not self-level. Keyboard assistance is restricted to practice. If controls seem difficult, use assisted practice first.

For slower laptops, open **Drone & Controls**, switch shadows off, and leave wind at zero. Performance has not been measured on the user's laptop.

## Obstacle geometry and passage checks

The 13 supplied stations use nine distinct generated shapes: circular ring, hexagon, zigzag (five upright poles with alternating passage sides), narrow precision gate, triple ring (any of its three openings), multi-frame corridor, covered tunnel, curved U-tunnel, and stacked KZ frame. Rings have polygonal curved boundaries; hexagons use their six-sided opening. Passage checks include the drone's 0.18 m collision radius and reject incorrect direction. Tunnel and corridor sections must be cleared in order. Frame collisions and tunnel covers have physical collision geometry.

Eight additional editor options are triangle, square, diamond, arch, ladder, dive ring, hurdle and flag turn. These are common racing/training shapes, not certified to any particular international competition specification. Dive rings are horizontal and must be crossed from above; flag-turn timing checks passage on the indicated side, not a complete orbit around the flag.

These are interpretations of the supplied photographs, not measured replicas. In particular, the U-tunnel curvature, zigzag, KZ proportions and dimensions need user review. The supplied layout and 10/20 ft intervals are approximate. Actual dimensions/orientations can now be changed in the editor.

## Assessment

Defaults: 3 laps, 160-second qualifying time, 200-second cutoff, 100 starting points; first crash deducts 20, second disqualifies. One point is deducted per completed five seconds above qualifying time. The incomplete time-bonus rule defaults to disabled (0); configure seconds per bonus point in the course editor after the rule is known. Score is clamped to zero at the low end.

Timing begins on the first gate's first valid passage and ends on the final section of the final station of the final lap. This first-gate timing is an approximation to the physical start-line rule. The lap loop continues from KZ back to the first ring. Pausing suspends time, so this build is not tamper-resistant competition judging software.

Contact versus crash uses pre-impact speed (3.5 m/s threshold), with a short cooldown to avoid repeated counts for one impact. This remains a heuristic requiring hardware/physics validation. Assessment uses calm conditions and Acro; current mass/rate/FOV settings remain configurable.

## Saved files and portability

The complete exported folder can be copied by USB. A shortcut alone does not contain the simulator. User courses, settings and results save under:

    %APPDATA%/Godot/app_userdata/DTC Flight Lab/

Files: course.json, settings.cfg, sessions.jsonl. Use the editor's Export and Results' CSV Export to copy data to USB. The executable is portable, but user records are stored per PC.

Course loading order: valid local saved course, valid course.json beside the executable, bundled course. Use **Restore supplied course** (with confirmation) to reset a saved layout. Invalid imports leave the current course intact. Settings/results from prototype 0.1 are not automatically migrated to the renamed application.

## USB radio setup

Connect a RadioMaster in USB Joystick mode. Open Drone & Controls, enable USB input, then map one axis at a time. Move that axis fully in both directions, return roll/pitch/yaw to centre, and confirm. Check live values and inversion. Throttle should read -1 at low power and +1 at high power; low throttle is required to start/resume. Changes in device connection pause flight. Calibration profiles use device GUID and name. If identical radios report identical IDs/names they share a profile.

**Beginner guide:** use the in-app Open beginner USB remote guide button or read REMOTE-SETUP.txt beside the Windows executable. It includes USB copying, Windows joy.cpl, Mode 2 mapping, calibration, live-value direction checks and troubleshooting.

RadioMaster Pocket/TX16 physical testing is pending. Automated axis-scaling checks do not prove real USB compatibility.

## Development and checks

Open project.godot in Godot 4.6.3, or:

    godot --path .
    godot --headless --path . --script res://tests/smoke.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/flight.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/yaw.gd
    godot --headless --path . --script res://tests/course_options.gd

Tests create local test results/settings. Set XDG_DATA_HOME to a separate temporary directory on Linux to keep test data separate from real records, and use a fresh directory for each smoke run. Smoke checks expect an empty results history.

Verified in the Linux cloud: 240 checks: 114 scene/geometry/editing/persistence/rules/axis checks, 96 new obstacle/spacing checks, 24 yaw checks and 6 keyboard-flight checks. Full turns in both directions were verified with both Q/E and Left/Right in practice and Acro assessment; the level test drone stayed within 0.05 m of its starting position. Rendered screenshots were reviewed using software OpenGL. Windows x86-64 export succeeded. Windows runtime, GPU/laptop performance, physical USB radios and correspondence to a real drone have not been verified.

Export with the matching official Windows templates installed:

    godot --headless --path . --export-release "Windows Desktop"

Cloud templates live under /workspace/fpv-tools/data/godot/export_templates/4.6.3.stable, selected by XDG_DATA_HOME=/workspace/fpv-tools/data. Downloaded official templates were verified against the release SHA512 list. No runtime downloads occur.

## Limitations and next acceptance work

This is a development release, not a finished commercial-grade replacement for Liftoff. Physics is a simplified thrust/drag/rate simulation; mass/rates and constant-force wind are experimental settings. There is no motor/PID/battery/aerodynamic calibration to the Luma 5. Wind realism, real-radio input and Windows behavior require practical testing. No goggles output, multiplayer, replay or full trainee-management system is included. Pilot names and session records are local; no online services are used. The Windows executable is unsigned: do not disable security protection to run it; report exact warnings for diagnosis.

Godot engine license: https://godotengine.org/license/ (MIT). Bundled DejaVu font license: assets/FONT-LICENSE.txt. All course/world geometry, interface and motor waveform are generated by this project; no Liftoff assets or code are used.

## Spacing controls (v0.3)

Choose station 02 or later in Course Editor. **Gap from previous (m)** changes its horizontal distance from the previous station's entry centre. **Move later stations together** is ON by default, so subsequent route gaps are preserved; switch it OFF to move only the selected station. **Whole-course spacing ×** scales all station positions about the first station while keeping obstacle dimensions and heights unchanged. A value of 2 doubles route gaps; 0.5 halves them. Values are cumulative against the displayed scale, so returning to 1 restores the previous scale.

These are centre-to-centre horizontal distances, not free space between obstacle edges. For Zig Zag, **Depth** is the full length of the pole line; five poles are spaced over that length. The map automatically adjusts its view to the edited layout. Editable station centres are limited to ±95 m; the decorative field boundary is 60 × 60 m. The editor permits layouts beyond that boundary. Spacing does not automatically orient gates or prevent overlapping geometry; check the 3D view after edits. Save the course to retain changes.

Saved v0.2 courses keep their dimensions, spacing and layout, but Zig Zag now renders as poles. To load the updated supplied layout with an 8 m pole line, first export any custom layout to preserve it, then choose Restore supplied course. Selecting Zig Zag again in the type list also applies its 8 m default depth.
