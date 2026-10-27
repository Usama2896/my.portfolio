# Your first changes — no coding experience needed

## What this software is made with

You can accurately say: “AL JEHAD FPV is an AI-assisted simulator built using
Godot 4.6.3, mainly in GDScript. I supplied its requirements and iterative flight
feedback. Python helps package Windows builds and run some tests.”

- Engine: Godot 4.6.3, native desktop app, Compatibility/OpenGL renderer.
- Main language: GDScript (.gd), Godot's own language. Its indentation resembles
  Python, but it is not Python and cannot run with the Python interpreter.
- UI: Godot Controls; 3D scene and collisions: Godot meshes and RigidBody3D physics.
- Radio: Godot joystick API over the operating system's USB joystick input.
- Storage: local JSON courses/results and ConfigFile settings. No SQL database,
  server or online account is required for playing.
- Python: packaging/build helpers and native mouse test; JavaScript/HTML: the
  optional offline radio diagnostic page; GitHub Actions: automated build runner.
- Windows output: AlJehadFPV.exe plus AlJehadFPV.pck. Keep them together.
- It is an independent prototype, not Liftoff source or calibrated aircraft physics.

## One small file for your four settings

Open this exact file in the repository:

`simulator/source/fpv-trainer/owner_settings.gd`

It currently contains:

```gdscript
extends RefCounted
# Owner-editable settings. Export Windows again after changing this file.
const ACTIVATION_KEY = "TWP29"
const SPLASH_SECONDS = 5.0
const GOD_MODE_LABEL = "god Mode"
const START_FULLSCREEN = true
```

- **Line 3**: the key. `TWP29` has no spaces. Keep the quotation marks when you
  change it, e.g. `const ACTIVATION_KEY = "MyNewKey29"`. It is case sensitive.
- **Line 4**: title duration in seconds. Change `5.0` to `2.0`, `7.0`, etc.
- **Line 5**: mode label. Change `"god Mode"` to your desired label. This controls
  the selector and live HUD. Longer descriptive paragraphs may still contain
  the old words; search `main.gd` to edit those too.
- **Line 6**: `true` starts fullscreen; `false` starts windowed unless goggles
  fullscreen is enabled. F11 already changes fullscreen while playing, without
  editing code. You do not need Ctrl+V for the attitude line; press V.

Line numbers can move after future edits. Search the constant's name if needed.
Do not change `project.godot`'s internal `DTC Flight Lab` name: that preserves the
existing calibration/course folder. The visible title is separate in `main.gd`.

## Easiest online route: edit on GitHub and let Actions rebuild

You need a browser, your GitHub login and Internet to BUILD. The finished app
still runs offline. Do not edit the binary EXE/PCK on GitHub.

1. Open https://github.com/Usama2896/my.portfolio
2. Above the file list, open the branch selector (it may say `main`). Select
   **fpv-simulator-prototype**. The simulator source is on this branch.
3. Click **simulator**, **source**, **fpv-trainer**, then **owner_settings.gd**.
4. Click the pencil **Edit this file**. You must be signed in as someone with
   permission to edit this repository.
5. Change one setting, keeping quotes, spelling and indentation intact.
6. Click **Commit changes**. Enter a short description, e.g. “Title lasts 7 seconds”.
   Commit to this branch if offered. If GitHub creates a new branch/pull request,
   that branch's push can also build; check its name when opening the run.
7. Click the repository's **Actions** tab. Look for **Build FPV Windows ZIP**.
   A source change automatically starts it. The first build downloads Godot and
   templates, so allow several minutes. GitHub may first ask you to enable Actions.
8. Open the run for YOUR commit. Wait for a green tick. A red cross means the
   build failed; open the failed step and read its error. Do not replace your
   working app with a failed build.
9. On the completed run page, scroll down to **Artifacts** and click
   **AL-JEHAD-FPV-Windows**. You must be signed in. Artifacts are retained 30 days.
10. Extract the downloaded artifact ZIP. Inside is **AL-JEHAD-FPV-Windows.zip**;
    extract that too. Open **AL-JEHAD-FPV/AlJehadFPV.exe**.
11. Confirm your change is visible. Keep the previous working version until then.

The workflow does not overwrite the repository's existing downloadable ZIP. The
fresh file is the artifact attached to your commit's Actions run. GitHub Actions
availability/quota depends on your repository/account. A manual Run workflow
button may be unavailable until the workflow exists on the default branch;
committing a source change triggers the push build on this branch anyway.

For a larger browser editor, press the `.` key while viewing the repository to
open github.dev. It edits files but does not compile Godot itself. Use the same
Actions steps afterward. A GitHub Codespace can run build commands but may have
usage charges; it is not needed for these small edits.

## Local route, if you prefer later

1. Install the standard Godot **4.6.3** editor (not the .NET edition). VS Code,
   Python and SQL are not required for these four GDScript edits.
2. Download this SOURCE BRANCH using Code > Download ZIP; extract it.
3. Open Godot > Import. Select `simulator/source/fpv-trainer/project.godot`.
4. Open `owner_settings.gd` in Godot's built-in script editor. Edit, save and
   press F6/F5 as appropriate (F5 runs the whole project) to test.
5. Editor > Manage Export Templates > install matching 4.6.3 templates.
6. Project > Export > Windows Desktop > Export Project (release).
7. Keep the new EXE and PCK together. To use the project's packaging helper,
   install Python 3 and run `python simulator/tools/package_windows.py` from
   the repository root after exporting to the preset's default path.

Editing source does not modify an app you already extracted. You must export or
use the Actions-built ZIP, then replace the EXE/PCK together while the app is closed.

## Activation behaviour and limits

The first run on each PC/Windows account asks for the owner key. Subsequent runs
reuse a machine-bound local activation file. Copying just the app folder onto a
different PC requires the key again. Moving the app folder on the same activated
PC/account does not. Changing the owner key and rebuilding requires activation
again. A different Windows user needs activation too.

This is a casual-copying deterrent, not strong DRM. The same key can activate
multiple PCs if the owner shares it. There is no server, activation count or
revocation service. Hardware/OS identity changes can require activation again.
The repository is public: a reader can see an editable key in the source, and a
skilled person can remove the check or run an older unprotected build. Do not
expect a secret hard-coded in public source to remain secret. For controlled
commercial distribution, keep future owner source/builds private and use a
stronger licensing design; making the repository private cannot erase old copies.

Activation and radio calibration are separate. Updating the app preserves both
on the same account. Saved calibration is not bundled in the distributable ZIP.
