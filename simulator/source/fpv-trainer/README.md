# AL JEHAD FPV OBSTACLE COURSE 0.7

Independent offline FPV simulator in Godot 4.6.3, using the Compatibility renderer. No Liftoff assets or interfaces are used. The Windows export needs no engine installation or network connection.

## Launch and preserved data

Run **AL-JEHAD-FPV/AlJehadFPV.exe** from the fully extracted ZIP. The two-second opening screen and runtime window title use the requested name. The internal Godot application identifier deliberately remains **DTC Flight Lab** so existing calibration, course files and records continue to load from:

    %APPDATA%/Godot/app_userdata/DTC Flight Lab/

Files: settings.cfg, course.json and sessions.jsonl. The executable folder is portable by USB; user records are per PC. Export courses/CSV results to carry them between computers. No migration, deletion or overwrite of existing user records is performed.

Course loading order is valid local saved course, valid course.json beside the executable, then bundled data. Restore supplied course asks for confirmation; export a custom course first to preserve it.

## Two explicit input buttons

Fly has an optional pilot name, a Practice/Acro Assessment mode list, and exactly two launch buttons:

- **Fly with Keyboard** sets keyboard input regardless of an old saved USB flag or a connected radio.
- **Fly with Remote** selects the current USB radio. No separate input-enable switch is required.

In v0.3 both old buttons called the same launch function using a saved USB flag. Enabling USB could therefore make the keyboard-labelled button fail remote checks too. v0.5 separates source selection from flight mode. Start blockers now open a visible setup dialog showing connection/mapping/calibration status and live throttle values, with Open Controls and Invert Throttle actions.

A configured remote opens the flight view first. The body remains frozen and motors stay off until throttle is low for 0.2 seconds; low throttle is required to arm/resume, rather than to open the view. Duplicate mapped channels and unfinished calibration are diagnosed. Connection changes pause remote flight. A chosen radio is remembered by GUID and name; identical devices reporting identical names/GUIDs share a profile.

## Keyboard and remote controls

Keyboard practice defaults to altitude assistance and auto-level. Up/Down climb/descend; releasing holds height approximately. W/S tilt forward/back; A/D bank left/right. Q or Left arrow turns left; E or Right arrow turns right. Momentum is not instantly braked. Enter pauses, R restarts, Esc returns to menu, F11 toggles full screen.

Ordinary remote practice and every assessment use Acro, with no auto-level or height hold. The separate optional Beginner Stabilized Practice mode adds assistance as described below. A usual Mode 2 mapping is right stick roll/pitch, left stick yaw/throttle. The FPV camera is attached to the drone; there is no separate gimbal. The heading display makes yaw rotation visible.

Read **REMOTE-SETUP.txt** in the Windows folder, or the in-app beginner guide in Drone & Controls. Select the intended radio, map one movement at a time, move through both endpoints, return roll/pitch/yaw to centre and confirm. For throttle, put it fully DOWN before confirming; this identifies its low end and automatically sets inversion. A mid-travel throttle confirmation is rejected. Cancel restores confirmed mappings; intermediate mapping changes are not persisted by unrelated settings saves.

Live directions should be roll-right +1, pitch-forward −1, yaw-right +1, throttle-low −1 and high +1. Use per-axis inversion and dead zone as needed. The user has reported working Windows detection/calibration on an earlier version; the revised start path still needs physical RadioMaster retesting.

## Four modules

- **Fly:** explicit input choice, practice/assessment, pilot name, FPV camera, targets, minimap, heading/speed/height/power/lap telemetry and generated motor sound.
- **Course Editor:** 17 obstacle types; add, duplicate, remove and reorder; edit dimensions, XYZ position, yaw/pitch/roll, individual pole offsets, station spacing and whole-course rotation; save/import/export JSON; adjust assessment rules.
- **Drone & Controls:** six size categories and measured-span override, camera FOV, mass, rates, practice wind, keyboard assistance, sound, shadows, radio selection and calibration.
- **Training Results:** local session history and CSV export. Latest 30 sessions are shown; export includes all. New records include input type, drone category and span.

## Drone size and collision clearance

The requested labels describe propeller class, not full airframe dimensions:

| Category | Approximate overall span preset |
|---|---:|
| 2.5 inch | 0.16 m |
| 5 inch | 0.30 m |
| 7 inch | 0.42 m |
| 10 inch | 0.60 m |
| 13 inch | 0.78 m |
| 16–17 inch | 1.02 m |

A measured overall span can override the preset (0.10–1.40 m). The collision sphere radius is half that span and is also supplied to gate clearance checks. This conservative spherical envelope may reject vertical clearances a flatter real airframe could pass. These are not exact manufacturer models. Size selection does not silently change mass/rates/thrust tuning or claim calibrated dynamics; flight tuning remains separate.

## Obstacles, poles and transforms

Types: circular ring, hexagon, five-pole Zig Zag, precision gate, triple ring, corridor, tunnel, U-tunnel, KZ, triangle, square, diamond, arch, ladder, dive ring, hurdle and flag turn. These are common training/racing shapes, not certified to any competition specification. The supplied 13-station course and dimensions are approximate interpretations of the photographs.

Zig Zag consists only of upright poles and bases, with alternating passage targets. Select a pole in the editor or drag its orange P1–P5 map point. Each pole has independent local X/Z offsets (±8 m); collision meshes and passage targets follow those positions. Depth is the base length of the five-pole line. Reset five poles clears their offsets. Timing still follows pole order 1→5, so create a flyable sequence when moving them forward/back.

Station X/Z are horizontal coordinates; Y is centre height. Yaw, pitch and roll fields accept ±360°. Rotation moves the entire obstacle without changing its local shape. A dive ring has an additional built-in −90° pitch to face upward; editor pitch is applied in addition. Passage detection uses the full transformed station basis. For nearly vertical stations the top-down pole drag cannot uniquely determine local X/Z, so it is blocked with an explanation; numeric pole fields still work.

Rotate whole course rotates station positions and headings about the first station, preserving dimensions, heights and horizontal gaps. It is separate from individual obstacle yaw. The environment/decorative field does not rotate.

Gap from previous measures horizontal entry-centre distance, not empty edge clearance. Move later stations together preserves later route gaps. Whole-course spacing scales station positions about station 1 without resizing obstacles or individual pole arrangements. The map fits the layout automatically. Station centres are limited to ±95 m; layouts can extend beyond the decorative 60 × 60 m boundary. Spacing does not automatically avoid geometry overlap.

Gate checks reject reverse/outside passages and use shape-specific openings plus the selected drone radius. Tunnel/corridor sections must be completed in order. A flag marker checks passage on the indicated side rather than a complete orbit. Triple/ladder gates allow any one of their openings.

## Assessment and physics limits

Defaults: 3 laps, 160-second qualifying time, 200-second cutoff, 100 points. First crash deducts 20; second disqualifies. Deduct one point per completed five seconds beyond qualifying time. Bonus seconds per point defaults to 0 (disabled) pending the incomplete supplied rule. Scores are clamped to zero at the low end.

Timing starts at the first valid gate passage and finishes at the final station of the final lap, an approximation to the physical start-line rule. Pausing suspends time; this is not tamper-resistant competition software. Assessment uses calm conditions and Acro; mass/rates/FOV remain configurable.

Flight uses simplified thrust/drag/rate control. Practice wind is an experimental constant-force approximation. Contact classification uses the strongest normal closing speed from PhysicsDirectBodyState3D, with a 3.5 m/s hard-impact threshold and cooldown. Direct-state contact vectors are already world-space. Hard impacts release steering control for 1.1 seconds, cut thrust, apply a bounded rebound/torque impulse, and let the rigid body tumble with reduced damping. Feedback includes a decaying camera offset/roll, flash and generated impact sound. Rebound material restitution is 0.28. Recovery preserves next station, lap, elapsed time and crash count, resets tunnel section progress, and places the drone near the current station entry. A remote recovery waits for low throttle before arming again. Assessment's second crash shows the impact before finishing as disqualified.

Practice has Crash Mode and God Mode. God Mode retains physical collisions and touch feedback but suppresses crash counting, motor cut and reset. It does not disable collision geometry. Assessment ignores a saved God preference and always enforces crash rules. The impact/recovery model is an approximation, not calibrated real-world damage dynamics. No motor/PID/battery/aerodynamic calibration to a real Luma 5 is established. No multiplayer, goggles output, replay or full trainee-management system is included.

## Development, tests and export

Open project.godot in Godot 4.6.3, or run:

    godot --path .

Use a separate, fresh XDG_DATA_HOME for each test on Linux, since tests write test courses/settings/results. Smoke tests expect an empty session history.

    godot --headless --fixed-fps 60 --path . --script res://tests/smoke.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/course_options.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/flight.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/yaw.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/remote_launch.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/customization.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/crashes.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/upward_tunnel.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/stability_visibility.gd
    godot --headless --fixed-fps 60 --path . --script res://tests/basic_guidance.gd
    node tests/radio_page.cjs

For the native mouse-click check on Linux, use an X11/Xvfb display with libXtst and run:

    DISPLAY=:99 python3 tests/popup_mouse.py

451 checks passed: 443 Godot checks (129 general, 101 obstacle/spacing, 6 keyboard flight, 24 yaw, 29 remote launch/arming/calibration, 38 customization/size, 24 impact/recovery, 47 upward-tunnel, 17 stability/visibility, 28 Basic/yaw/guidance), seven JavaScript radio-page checks and one native rendered popup mouse-click check. The controller_input.gd adapter wraps native Godot input. Remote tests inject deterministic device/axis reports through that same interface and verify actual button signals, launch state, throttle-driven physics, inversion, calibration cancellation/persistence and disconnect behavior. This is distinct from physical USB testing. Clearance tests check both analytic gate progression and actual collisions for different sizes.

Rendered screenshots were inspected using software OpenGL. Windows export and packed-resource startup were checked in Linux. Physical Windows performance and the revised TX16/Pocket launch require user retesting. The executable is unsigned; report warnings without disabling protection.

With official matching export templates installed:

    godot --headless --path . --export-release "Windows Desktop"

Output: build/al-jehad-windows/AlJehadFPV.exe and its matching PCK. Include external course.json, guides and licenses in the USB package. Cloud templates live under /workspace/fpv-tools/data/godot/export_templates/4.6.3.stable, selected using XDG_DATA_HOME=/workspace/fpv-tools/data. Official template SHA512 checksums were verified during setup. No runtime downloads occur.

Godot engine: MIT, assets/GODOT-LICENSE.txt. DejaVu fonts: assets/FONT-LICENSE.txt. Geometry, UI and motor waveform are generated locally by this project.

## Local browser radio diagnostic

RADIO-TEST.html is included beside the executable and as data/radio-test.html in the resource pack. Controls can extract a versioned copy into the app data directory and open it in the default browser. The Gamepad API reads only controllers attached to the user's local machine. A user activation and initial focused window may be required; some browsers restrict local-file Gamepad access. In-app Copy Remote Report is the fallback. Nothing is sent over the network; CSP disables network connections. Reports contain device/axis and browser or game launch information, not credentials. Browser raw-axis indices may differ from Godot's controller mapping.

Native popup tests use actual XTest pointer clicks with injected controller reports. Headless button-signal tests alone do not establish native mouse hit testing. The popup's Start button now opens a disarmed flight view when configuration is valid, irrespective of high throttle; it does not bypass low-throttle motor arming. Runtime reports include last launch state, current source, endpoints, inversion and raw/scaled axes to diagnose remaining hardware-specific failures without guessing a driver issue.

## V0.6 upward tunnel, visibility and beginner assistance

The u_tunnel identifier is retained, so existing saved courses receive the replacement geometry without resetting station dimensions or user edits. It has a straight horizontal entry along local −Z, a quarter-circle elbow toward +Y, and a vertical open neck. Bend radius is max(1.25, opening_height × 0.65); neck length is max(0.8, opening_height × 0.5). Depth controls the straight entry length. These are proportional approximations to the supplied photo, not measured dimensions.

Ten sections carry centre and Basis transforms. Progression and clearance use each section's own plane, including upward crossing at the final outlet. The generated net uses alpha-scissored threads for visibility; its continuous collision shell prevents passage through the visual net holes. Ring supports and joints leave the inlet, centre path and top opening clear. Whole-station yaw/pitch/roll still transforms the full route.

High visibility brightens only obstacle materials and modestly increases ambient energy. It is reversible and does not accumulate colour changes. Procedural labels are explicitly tracked with owned=false, show the current target during flight by default, and hide within 2.5 m to avoid covering the camera. The editor retains all labels. A Closer view button sets FOV to 80; physical geometry is unchanged.

Beginner Stabilized Practice is opt-in. Steering is exponentially smoothed (rate 8/s), pitch/roll target about ±15°, and yaw is gentler. Releasing controls self-levels; centred pitch/roll add horizontal braking. For remote input, throttle near 50% holds vertical speed at zero, higher/lower commands climb/descent, and input ≤10% cuts thrust. Low-throttle arming/recovery remains mandatory. Keyboard uses the existing climb/descend keys. Ordinary remote Practice is unchanged Acro; assessment always bypasses assistance even if the preference is saved.

New control/visibility preferences are stored in the existing settings file. Session/CSV records include control_mode to distinguish Beginner Stabilized, Keyboard Assist and Acro. All assistance is an approximate training aid and has not been calibrated to a real aircraft.

## V0.7 Basic guided mode and independent yaw

Practice yaw uses yaw_rate (default 180°/s, range 45–540) rather than the previous hard-coded stabilized yaw limit (1.2 rad/s). Basic uses yaw_rate × 0.8; assessment deliberately uses the existing rates value. Pitch/roll stays independent. Keyboard and radio full-stick direction conventions remain unchanged. The simulation's angular damping/smoothing means measured short-turn totals are lower than the nominal rate.

Basic Guided Practice is opt-in and is an additional practice level. Selecting it initially selects God Mode; the user can still choose Crash Mode. It holds a level horizon and commands slow yaw-relative horizontal velocity rather than requiring continuous manual banking. A 3/s velocity-feedback force cancels the horizontal component of motor force; diagonal movement is limited to basic_speed (default 1.8 m/s, range 0.5–4). Centred controls brake toward zero velocity. Height assistance uses slower climb/descent than Beginner. Fully low remote throttle cuts thrust. Existing low-throttle arming/checkpoint logic stays in force. Basic ignores practice wind; other practice modes retain it.

Guidance is split into guidance.gd (visual 3D path/ghost/centre plus) and flight_guidance.gd (2D centre crosshair, target reticle, edge arrows and instructions). Path samples use the actual obstacle section basis, including the upward U-tunnel and selected fitting hole for triple/ladder gates. Wrong-side approach aims toward a valid preceding entry point. Oversized envelopes show a warning and hide the ghost/path. Ghosts/breadcrumbs have no collision objects, triggers or flight controls and never call gate progression. They hide near the camera to avoid obstructing the pilot. Gate-clear feedback is triggered only by the actual progression function.

Guidance and Basic controls are disabled in assessment even if preferences are saved. The existing ordinary Practice and Beginner modes remain. New preferences persist in the existing settings file; session/CSV records include Basic Guided control_mode and the effective yaw_rate_deg.

The guide is an illustrative centre route, not obstacle avoidance or an autopilot. Arbitrarily overlapping or badly ordered custom courses can still be impossible. Existing crash and physical clearance rules remain authoritative. Basic's force assistance is intentionally an easy learning aid, not real quadcopter dynamics.

## Version 0.8

See ../../README.md for release behaviour and controls. `experience.gd` owns
weather appearance, noncolliding route geometry, flight battery, cue audio and
optional native gamepad rumble. `attitude.gd` draws the world-up-derived moving
reference independently of Basic guidance. Settings remain in the existing
profile, preserving device calibration and courses. Assessment wind stays calm;
battery is an explicit configurable option that applies to all modes.
