# Three-PC LAN competition — beginner guide (v0.9)

Use **three PCs**, one USB radio and one FPV view per pilot. PC 1 hosts and also
flies as Pilot 1. PCs 2 and 3 join as Pilots 2 and 3 in join order. Each pilot
flies a separate drone for one relay leg. No dedicated server or Internet service
is needed. Wired Ethernet is recommended; Wi-Fi between PCs can work too.

## Equipment and connections

- Connect all PCs to the SAME router or Ethernet switch. An Internet connection
  is not required; the router can provide local addresses without Internet.
- Plug each RadioMaster TX16/Pocket into its OWN PC using a data-capable USB cable.
  Select USB Joystick/HID mode on the radio. Its USB connection does not need Wi-Fi.
  No additional radio receiver board is needed if Windows already detects the
  radio as a working USB joystick, as in your existing single-player tests.
- Install/extract the SAME v0.9 package on every PC. Each PC/account needs its own
  one-time owner activation. Existing saved calibration loads automatically.
- Test keyboard or radio input in solo Fly first. Map/calibrate only if needed.
- Goggles are a separate VIDEO connection to that pilot's PC. Use the existing
  fullscreen/goggles option and read GOGGLES-SETUP.txt for the exact Cobra model's
  AV/HDMI requirements. LAN does not transmit directly into analogue goggles.

Godot/Windows can enumerate multiple USB joystick devices on one PC, and our
selector can choose among them. That is different from providing three independent
views. This release uses one local pilot per game instance on three PCs; it does
not add three-radio split-screen on a single PC. Three physical RadioMaster units
on one Windows PC have not been tested here.

## First relay test — follow this order

1. On PC 1 press Windows+R, type `cmd`, and press Enter. Type `ipconfig` and press
   Enter. Under the active Ethernet/Wi-Fi adapter, note its **IPv4 Address**, for
   example `192.168.1.20`. Use that local address, not a public Internet address.
   The app also shows possible host addresses in the LAN panel.
2. On PC 1 open **LAN Competition**. Enter the pilot name. Choose **Team Relay**,
   then **Mountain valley**, **Desert plain** or **City streets**.
3. Adjust the host settings below the connection buttons BEFORE hosting:
   each leg distance 30–5000 m, landing-zone diameter, landing hold, qualifying
   time, maximum time, scoring and shared control level. Scroll if needed.
   Defaults: 50 m per leg, 2 ft / 0.6096 m LZ diameter, 1 s hold, QT 180 s,
   maximum 240 s, 100 completion + 100 landing bonus.
4. For your first connectivity test, try a 2 m LZ diameter and Easy controls.
   Once tested, restore the strict event size. The drone's whole conservative
   size envelope must fit the zone: a 16–17 inch drone cannot fit a 2-foot LZ.
5. Keep UDP port **24567** on all PCs, then click **HOST — create room** on PC 1.
   If the port is already in use, choose another port on all PCs.
6. If Windows asks about network access, allow this app on your trusted **Private**
   network. Do not disable the firewall or open Internet/router forwarding ports.
7. On PC 2 open LAN Competition, enter its pilot name and PC 1's IPv4 address.
   Use the same UDP port and click **JOIN — connect to host**. Repeat on PC 3.
   Join PC 2 first if you want it to fly leg 2. Host settings override clients'
   local terrain/course/control choices for this match only.
8. On EACH PC choose **Ready with USB Remote** or **Ready with Keyboard**.
   For USB, keep throttle fully low for arming. The list must show all three
   pilots READY. The host cannot start with an unready/missing pilot.
9. PC 1 clicks **START — all pilots must be ready**. A five-second countdown
   switches everyone to their own FPV view. Keep launch controls untouched.
10. Pilot 1 flies SP → LZ1. Pilots 2 and 3 wait with throttle fully low. Follow
    the route/map, yellow target and remaining-distance display.
11. Land fully inside LZ1, near level, at no more than 0.6 m/s, and remain settled
    for the host's hold time. The whole drone envelope must be within the circle.
    A momentary touch or flying over the pad does not complete a leg.
12. When PC 2 displays **YOUR TURN**, Pilot 2 may take off from their station and
    fly LZ1 → LZ2. USB arming checks low throttle again before this leg.
13. Pilot 3 then flies LZ2 → LZ3. The final settled landing stops the team timer.
14. Open **LAN Competition** after the round to see results. **NEW ROUND** keeps
    the room/rules and asks everyone to ready again. Disconnect to change terrain
    or course. Each pilot keeps their own FPV/goggles view and saved calibration.

## Rules and scoring

- Three separate drones; one relay leg per pilot. Join order assigns legs.
- Shared host clock starts AFTER countdown, includes handoffs/re-arming and never
  pauses for local menus. Enter/R cannot pause/restart the shared round.
- During countdown or another pilot's turn, throttle above 15% or keyboard launch/
  movement keys count as an attempted false start. Waiting drones are held still;
  the attempt still disqualifies the team. Wait for YOUR TURN on your own screen.
- Hard collision, false start, settled landing outside the designated zone,
  maximum-time expiry, pilot disconnect or lost telemetry disqualifies the relay
  team. A light contact is not automatically a hard crash; use smooth landings.
- On completion: 100 points, plus 100 landing bonus if all three valid landings
  finish within qualifying time. Add one point for every FULL five seconds
  faster than QT; subtract one for every FULL five seconds slower. Scores bottom
  at zero. The host can edit base points and landing bonus. Maximum time is a
  separate disqualification threshold. This uses your chosen 100+100 scheme,
  not the inconsistent “20 MKS” heading in the original sheet.
- Calm air and no battery limit are enforced in this competition release so
  every pilot uses the same conditions and long-distance legs remain possible.
  Solo weather/battery/assist preferences are restored when you leave the room.
- Drone-to-drone collisions are off. Terrain, buildings and obstacle collisions
  still count. LAN telemetry is for trusted local competition, not anti-cheat or
  a certified real-aircraft physics model. Disconnecting the host ends the room;
  this release has no host migration or in-progress reconnect/resume.

## Two- or three-player obstacle race

1. On the HOST, edit/save the course in Course Editor first: obstacles, dimensions,
   positions, rotations, spacing and laps. Clients do not need to copy course.json.
2. Choose **Obstacle Race — 2 or 3 pilots** in LAN Competition before hosting.
3. Other PCs join and everyone readies. Host clicks START when 2 or 3 are ready.
4. Everyone flies their own drone simultaneously. The host checks directional
   gate/section crossings and lap completion. The shared clock starts after the
   countdown. The host's LAN maximum/QT settings apply, not solo assessment time.
5. A crash disqualifies THAT racer; remaining racers continue. Finishers rank by
   elapsed time. Relay landing bonus does not apply to obstacle races.
6. The host course is synchronized temporarily. Clients' own saved courses are
   restored on leaving; the received course is not written over their course file.

## Leaderboard and CSV

The live board shows pilot slots, readiness, turn and result. Completed matches
are saved locally on each connected PC in `lan-results.jsonl`, under the existing
DTC Flight Lab app-data directory. Open **saved LAN leaderboard** to review them.
Use **Export LAN results CSV** to choose a file you can copy to USB. CSV includes
timestamp, mode, terrain, result, pilot, time, points and disqualification reason.
Relay rows show each pilot's cumulative handoff time and the shared team score.
If the host abruptly disappears, unfinished clients stop; a completed result is
not invented. Host-issued abort results are retained on the host when possible.

## If JOIN does not work

- Confirm host is open, same version/protocol, correct LOCAL IPv4 and UDP port.
- Confirm all PCs use the same LAN. Some guest Wi-Fi/phone hotspots isolate clients;
  use ordinary LAN Ethernet/router ports or turn off guest isolation as appropriate.
- Check Windows marks your trusted LAN Private and permits this app on that profile.
- Avoid VPN/virtual-adapter addresses in ipconfig. Try the active Ethernet/Wi-Fi IPv4.
- Check Windows actually sees the radio, then test its axes in Drone & Controls.
  A network connection problem is different from USB calibration.
- Each match is locked against late joins during countdown/racing. A dropped pilot
  must wait for a new round/room; races do not silently resume after a disconnect.

## What was verified

Automated rule checks plus real ENet loopback runs with three separate Godot
processes for relay, three-player obstacle racing, two-player obstacle racing and
an active-round disconnect. Result agreement, CSV, temporary course sync and solo
restoration were checked. Terrain/FPV screens were rendered and inspected.
These are cloud/Linux tests, not a claim of physical three-PC Windows/radio/
goggles testing or Call of Duty-level visuals. Try a short keyboard LAN round
first, then the three radios and goggles, before using strict event scoring.


## Version 0.10 spectator and menu update

Waiting and finished pilots now automatically watch the active relay pilot.
Auto / P1 / P2 / P3 / Mine buttons select a read-only camera. Number keys 1/2/3
select a pilot and 0 selects automatic follow. Your own flight camera always
returns when it is your turn. These are views rendered from synchronized drone
poses; they do not transmit another PC's desktop or grant control of its drone.
Esc opens a menu with Resume, Windowed/Fullscreen and Exit. In LAN the flight
and shared clock continue while this menu is open. Leaving the session or exiting
still disconnects, so use Resume to return without withdrawing.
