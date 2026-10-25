# FPV Digital Training Course — initial prototype

Independent, offline Godot 4.6.3 project using the Compatibility renderer. No Liftoff installation, account, online assets, or network connection is required at runtime.

## Current prototype

- FPV camera, gravity, thrust, and basic non-self-leveling rate control.
- 13 named stations with approximate positions derived from the supplied layout.
- All obstacles currently use rectangular placeholder frames, including named rings/tunnels. These are NOT accurate replicas yet.
- Sequential directional gate checks, three laps, 200-second cutoff, basic impact threshold, first-crash deduction and second-crash disqualification.
- Local JSONL session results. Time bonus is disabled until its incomplete rule is clarified.
- Keyboard development controls and generic USB game-controller axes. F1–F4 map roll, pitch, yaw and throttle. Defaults assume a conventional joystick layout. Axis inversion, endpoint/dead-zone calibration, per-device profiles and device testing are still required. Keep the throttle low before starting.

## Run source

Open project.godot in Godot 4.6.3 and press F6/F5, or run:

    godot --path /workspace/fpv-trainer

Enter starts/pauses; R restarts the whole run. W/S pitch, A/D roll, Q/E yaw, Up/Down gradually adjust throttle. No automatic leveling. Keyboard input is for development; it cannot establish real-radio compatibility.

Edit data/course.json to add/remove gates or change dimensions (metres), positions and yaw. A graphical course editor is not implemented yet. The external course.json alongside an exported executable takes precedence over bundled data.

## Portable Windows target

Copy the entire exported Windows folder to the destination PC or USB, then run FPVTrainer.exe. A shortcut alone does not contain the software. No Godot installation is needed on that PC. Session results and controller settings are saved in the Windows user's Godot app-data directory, not on the USB. A portable executable does not yet mean portable user records.

Windows execution and real controller operation have not been tested in this Linux cloud workspace. Rendering speed, drone realism and training transfer have not been validated.

## Validation

    godot --headless --path /workspace/fpv-trainer --script res://tests/smoke.gd

Checks actual scene construction, outside/reverse gate rejection, three-lap completion and reset. Test results use a separate XDG_DATA_HOME in cloud runs to avoid mixing with real trainee records.

## Next implementation work

Accurate obstacle meshes and collision boundaries; start/finish detection distinct from pressing Enter; crash/contact classification; full controller calibration and hot-plug safety; local trainee profiles; instructor dashboard; visual course editor; configurable assessment rules; real-drone tuning; wind; Windows and hardware acceptance tests. Existing crash detection is a speed-threshold approximation, not reliable crash classification. Timer currently starts on Enter rather than crossing a start line.
