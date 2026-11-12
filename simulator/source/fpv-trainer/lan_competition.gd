extends Node3D
const RULES = preload("res://competition_rules.gd")
const TERRAIN = preload("res://competition_terrain.gd")
const O = preload("res://obstacles.gd")
const PROTOCOL = 1
var host: Node
var rules = RULES.new()
var connected := false
var prepared := false
var room_world: Node3D
var ghosts: Dictionary = {}
var backup: Dictionary = {}
var board: Label
var race_map: Control
var race_board: Label
var wire: Dictionary = {}
var accumulator := 0.0
var last_phase := ""
var last_turn := -1
var last_gate := -1
var result_saved := false
var address := "192.168.1.10"
var port := 24567
var options: Dictionary
var race_course: Dictionary = {}
var local_input := false
var last_message := "Host a room or enter the host PC's local IPv4 address."
var overlay_marker: Label3D
var local_id := 1
var connecting := false
var connecting_time := 0.0
func _ready() -> void:
	name = "LANCompetition"
	options = rules.options.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load("user://lan-room.cfg")==OK:
		var stored = cfg.get_value("room","options",{})
		if stored is Dictionary and valid_options(stored): options = stored
		address = str(cfg.get_value("room","address",address))
		port = clampi(int(cfg.get_value("room","port",port)),1024,65535)
	multiplayer.peer_disconnected.connect(peer_left)
	multiplayer.connected_to_server.connect(connected_to_room)
	multiplayer.connection_failed.connect(connection_failed)
	multiplayer.server_disconnected.connect(server_left)
func live() -> bool: return connected and rules.phase in ["countdown","running"]
func menu() -> void:
	host.content.add_child(host.label_("LAN COMPETITION",26,"79e5c2"))
	host.paragraph("One PC + one USB radio + one FPV view per pilot. Offline local network; no Internet service or account. Connect PCs to the same router/switch.")
	var pilot := LineEdit.new()
	pilot.editable = not connected
	pilot.text = host.trainee
	pilot.placeholder_text = "Pilot name"
	pilot.text_changed.connect(func(v): host.trainee = v.strip_edges().left(40))
	host.content.add_child(pilot)
	if not connected:
		var mode := OptionButton.new()
		mode.add_item("Team Relay — exactly 3 pilots")
		mode.add_item("Obstacle Race — 2 or 3 pilots")
		mode.select(options.mode)
		mode.item_selected.connect(func(i): options.mode = i)
		host.content.add_child(mode)
		var terrain := OptionButton.new()
		for title in ["Mountain valley","Desert plain","City streets"]: terrain.add_item(title)
		terrain.select(options.terrain)
		terrain.item_selected.connect(func(i): options.terrain = i)
		host.content.add_child(terrain)
		connection_fields()
		host.paragraph("Adjust the host settings below BEFORE creating the room. Joining always uses the host settings.")
		for i in range(3): host.field("Leg %d distance m" % [i+1],options.legs[i],30,5000,10,func(v): options.legs[i] = v)
		host.field("LZ diameter m (2 ft = .61)",options.radius*2,0.6096,10,0.05,func(v): options.radius = v/2)
		host.field("Landing hold seconds",options.settle,0.5,5,0.5,func(v): options.settle = v)
		host.field("Qualifying seconds",options.qualifying,10,36000,10,func(v): options.qualifying = v)
		host.field("Maximum seconds",options.maximum,10,36000,10,func(v): options.maximum = v)
		host.field("Completion points",options.base,0,1000,10,func(v): options.base = int(v))
		host.field("All-landings bonus",options.landing_bonus,0,1000,10,func(v): options.landing_bonus = int(v))
		var control := OptionButton.new()
		for title in ["Easy guided controls","Stabilized controls","Acro controls"]: control.add_item(title)
		control.select(options.controls)
		control.item_selected.connect(func(i): options.controls = i)
		host.content.add_child(control)
		host.paragraph("Leg distances and LZ settings apply to Relay. Obstacle Race uses the dimensions, spacing and laps in the host Course Editor.")
		host.paragraph("Host rules apply to everyone. Relay: crash, false start, outside-LZ landing or maximum time = team DQ. Landing needs low speed and a level drone. Obstacle race uses the host's current edited course. LAN races use calm air and no battery limit; solo settings are restored on leaving.")
		host.paragraph("Host IPv4 candidates: "+local_addresses()+"\nAllow this app on Windows Private networks only. Do not open router ports. Each PC needs its own activation and saved USB calibration.")
	else:
		host.paragraph("ROOM OPEN · "+("HOST" if multiplayer.is_server() else "CLIENT")+" · UDP "+str(port)+"\nHost IPv4: "+local_addresses() if multiplayer.is_server() else "CONNECTED TO "+address)
		host.button_("Ready with Keyboard",func(): prepare_local(false),null,true)
		host.button_("Ready with USB Remote",func(): prepare_local(true))
		if multiplayer.is_server():
			host.button_("START — all pilots must be ready",request_start)
			host.button_("NEW ROUND — same room",request_reset)
		if prepared: host.button_("Return to FPV view",func(): host.menu.hide(); host.camera.current = true; host.hud.show())
		host.button_("Disconnect / return to solo",disconnect_room)
	board = host.label_("",14,"d8eadf")
	board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.content.add_child(board)
	host.button_("Export LAN results CSV…",export_csv)
	host.button_("Open saved LAN leaderboard",show_history)
	host.paragraph("Goggles keep using this PC's video output: Drone & Controls > Goggles mode. USB radios do not carry goggles video. Drone-to-drone collisions are disabled; ground/building/obstacle contacts still count.")
func local_addresses() -> String:
	var ips := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.contains(".") and not ip.begins_with("127.") and not ip.begins_with("169.254."): ips.append(ip)
	return ", ".join(ips) if not ips.is_empty() else "Use Windows ipconfig > IPv4 Address"
func host_room() -> void:
	if connected or connecting: return
	if not host.license_memory.is_active(): last_message = "Activate this PC first."; return
	if not valid_options(options): last_message = "Maximum time must be at least qualifying time."; return
	save_room_preferences()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port,2,3)
	if error!=OK: last_message = "Cannot host on UDP %d (error %d). Choose a free port." % [port,error]; return
	multiplayer.multiplayer_peer = peer
	connected = true
	local_id = 1
	rules = RULES.new()
	rules.options = options.duplicate(true)
	race_course = host.course.duplicate(true)
	rules.course = race_course
	rules.add_player(1,host.trainee,host.drone_span)
	configure_world()
	last_message = "Room hosted. Other PCs: join this PC's IPv4, UDP %d." % port
	publish()
	host.show_module("LAN Competition")
func join_room() -> void:
	if connected or connecting: return
	if not host.license_memory.is_active(): last_message = "Activate this PC first."; return
	if not address.is_valid_ip_address(): last_message = "Enter the host's local IPv4 address, e.g. 192.168.1.10."; return
	save_room_preferences()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address,port,3)
	if error!=OK: last_message = "Cannot create LAN connection (error %d)." % error; return
	multiplayer.multiplayer_peer = peer
	connecting = true
	connecting_time = 0
	last_message = "Connecting… check same LAN, host IP, UDP port and Windows Private-network firewall."
func connected_to_room() -> void:
	connecting = false
	connected = true
	local_id = multiplayer.get_unique_id()
	register.rpc_id(1,PROTOCOL,host.trainee,host.drone_span)
func connection_failed() -> void:
	connecting = false
	last_message = "Could not connect. Check host IP/port, LAN cable/router and Private-network firewall."
	disconnect_room(false)
func server_left() -> void:
	last_message = "Host disconnected. The race cannot continue; solo settings restored."
	disconnect_room(false)
func peer_left(id: int) -> void:
	if not connected or not multiplayer.is_server(): return
	if live(): rules.disqualify(id,"Pilot disconnected")
	elif rules.phase=="lobby" and id in rules.players:
		rules.players.erase(id)
		rules.order.erase(id)
	publish()
@rpc("any_peer","call_remote","reliable",0)
func register(protocol: int, title: String, span: float) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if protocol!=PROTOCOL or live() or rules.order.size()>=3 or not is_finite(span):
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	rules.add_player(sender,title,span)
	setup.rpc_id(sender,PROTOCOL,options,race_course)
	publish()
@rpc("authority","call_remote","reliable",0)
func setup(protocol: int, settings: Dictionary, course_: Dictionary) -> void:
	if protocol!=PROTOCOL or not valid_options(settings) or not host.valid_course(course_):
		last_message = "Incompatible or invalid host room. Install the same simulator version on all PCs."
		disconnect_room(false)
		return
	options = settings.duplicate(true)
	race_course = course_.duplicate(true)
	rules = RULES.new()
	rules.options = options
	rules.course = race_course
	configure_world()
	host.show_module("LAN Competition")
func valid_options(settings: Dictionary) -> bool:
	for key in ["mode","terrain","radius","settle","qualifying","maximum","controls","base","landing_bonus"]:
		if not (settings.get(key) is float or settings.get(key) is int) or not is_finite(float(settings[key])): return false
	if not settings.get("legs") is Array or settings.legs.size()!=3: return false
	for distance_ in settings.legs:
		if not (distance_ is int or distance_ is float) or not is_finite(float(distance_)) or distance_<30 or distance_>5000: return false
	return settings.mode in [0,1] and settings.terrain in [0,1,2] and settings.controls in [0,1,2] and settings.radius>=0.3048 and settings.radius<=5 and settings.settle>=0.5 and settings.settle<=5 and settings.qualifying>=10 and settings.maximum>=settings.qualifying and settings.maximum<=36000 and settings.base>=0 and settings.base<=1000 and settings.landing_bonus>=0 and settings.landing_bonus<=1000
func configure_world() -> void:
	if backup.is_empty():
		backup.course = host.course.duplicate(true)
		for key in ["practice_basic","practice_stabilized","practice_god_mode","assisted","battery_enabled","wind","weather","fov"]: backup[key] = host.get(key)
	for item in host.solo_world_nodes:
		if is_instance_valid(item):
			if item is Node3D: item.hide()
			if item is CollisionObject3D: item.collision_layer = 0
	if is_instance_valid(room_world): room_world.queue_free()
	room_world = Node3D.new()
	room_world.name = "CompetitionTerrain"
	add_child(room_world)
	TERRAIN.build(room_world,options,rules.stations())
	host.course = race_course.duplicate(true)
	host.rebuild_course()
	host.gate_root.visible = options.mode==1
	for shape in host.gate_root.find_children("*","CollisionObject3D",true,false): shape.collision_layer = 1 if options.mode==1 else 0
	host.experience.route.visible = options.mode==1 and host.ground_route
	host.practice_basic = options.controls==0
	host.practice_stabilized = options.controls==1
	host.assisted = options.controls!=2
	host.practice_god_mode = false
	host.battery_enabled = false
	host.wind = 0
	host.weather = 0
	host.experience.apply_weather()
	host.camera.far = 16000
	host.overview.far = 16000
	host.overview.position = Vector3(20,25,30)
	host.overview.look_at(Vector3(-20,0,-20))
	overlay_marker = Label3D.new()
	overlay_marker.text = "NEXT LANDING ZONE"
	overlay_marker.visible = false
	overlay_marker.font_size = 80
	overlay_marker.pixel_size = 0.015
	overlay_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	room_world.add_child(overlay_marker)
	if not is_instance_valid(race_board):
		race_board = host.label_("",17,"caffdf")
		race_board.position = Vector2(460,124)
		race_board.add_theme_color_override("font_shadow_color",Color.BLACK)
		race_board.add_theme_constant_override("shadow_offset_x",2)
		race_board.add_theme_constant_override("shadow_offset_y",2)
		host.overlay.add_child(race_board)
		race_map = preload("res://competition_hud.gd").new()
		race_map.lan = self
		race_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.overlay.add_child(race_map)
func prepare_local(radio: bool) -> void:
	if not connected or rules.phase!="lobby": last_message = "Wait for the host to reset the room before readying."; return
	if not local_id in rules.players: last_message = "Waiting for host roster…"; return
	if prepared: last_message = "Already ready. Host can start when every pilot is ready."; return
	host.use_radio = radio
	host.poll_radio()
	if not host.start_flight(false): last_message = host.status; return
	prepared = true
	host.menu.show()
	local_input = radio
	var pose := spawn_pose(local_id)
	host.drone.request_reset(pose)
	host.drone.freeze = true
	host.active = false
	host.previous_position = pose.origin
	last_message = "Ready at your station. Keep throttle fully LOW until your turn. Host starts the round."
	if multiplayer.is_server(): rules.players[1].ready = not radio
	else: ready_request.rpc_id(1,not radio)
func spawn_pose(id: int) -> Transform3D:
	var index := maxi(0,rules.order.find(id))
	var position_ := Vector3.ZERO
	var yaw := 0.0
	if options.mode==0:
		position_ = rules.stations()[mini(index,2)]
		var direction: Vector3 = rules.stations()[mini(index+1,3)]-position_
		yaw = atan2(-direction.x,-direction.z)
	else:
		var gate: Node3D = host.gates[0]
		position_ = gate.to_global(O.sections(host.course.gates[0])[0].center+Vector3((index-1)*0.65,0,3.5))
		yaw = gate.rotation.y
	position_.y = host.drone_span/2+0.02
	return Transform3D(Basis(Vector3.UP,yaw),position_)
@rpc("any_peer","call_remote","reliable",0)
func ready_request(ready_: bool) -> void:
	if not multiplayer.is_server() or rules.phase!="lobby": return
	var sender := multiplayer.get_remote_sender_id()
	if sender in rules.players: rules.players[sender].ready = ready_
func request_start() -> void:
	if not connected or not multiplayer.is_server(): return
	if not rules.begin(): last_message = "Relay needs exactly 3 ready pilots; obstacle race needs 2–3. LZ diameter must exceed every drone span."; return
	last_message = "Countdown started — no takeoff before your turn."
	publish()
func request_reset() -> void:
	if connected and multiplayer.is_server() and rules.phase in ["lobby","finished"]:
		for id in rules.order.duplicate():
			if id!=1 and not id in multiplayer.get_peers(): rules.order.erase(id); rules.players.erase(id)
		reset_round.rpc()
@rpc("authority","call_local","reliable",0)
func reset_round() -> void:
	rules.phase = "lobby"
	rules.elapsed = 0
	rules.leg = 0
	rules.outcome = ""
	for id in rules.order:
		rules.players[id].ready = false
		rules.players[id].result = "Waiting"
	prepared = false
	result_saved = false
	last_turn = -1
	last_phase = ""
	host.leave_flight()
	host.show_module("LAN Competition")
func _physics_process(delta: float) -> void:
	if connecting:
		connecting_time += delta
		if connecting_time>10: connection_failed()
	if not connected:
		if is_instance_valid(board): board.text = last_message
		return
	if prepared:
		if local_input and host.joystick<0: notify_event("USB radio disconnected")
		var position_: Vector3 = host.drone.position
		if multiplayer.is_server(): rules.report(local_id,position_,host.drone.rotation,host.drone.linear_velocity)
		else: motion.rpc_id(1,position_,host.drone.rotation,host.drone.linear_velocity)
		var armed: bool = not host.remote_waiting_low and (not local_input or (host.joystick>=0 and host.remote_configuration_issue().is_empty()))
		if rules.phase=="lobby":
			if multiplayer.is_server(): rules.players[local_id].ready = armed
			else: ready_request.rpc_id(1,armed)
	if multiplayer.is_server():
		rules.tick(delta)
		accumulator += delta
		if accumulator>=0.1: accumulator = 0; publish()
	apply_local_state()
	if not prepared and host.module=="LAN Competition": host.status = last_message
	refresh_board()
@rpc("any_peer","call_remote","unreliable_ordered",1)
func motion(position_: Vector3, rotation_: Vector3, velocity_: Vector3) -> void:
	if not multiplayer.is_server(): return
	var sender := multiplayer.get_remote_sender_id()
	if not sender in rules.players: return
	if position_.length()>20000 or velocity_.length()>300: rules.disqualify(sender,"Invalid flight telemetry"); return
	rules.report(sender,position_,rotation_,velocity_)
func publish() -> void:
	var state := {"players":rules.players.duplicate(true),"order":rules.order.duplicate(),"phase":rules.phase,"countdown":rules.countdown,"elapsed":rules.elapsed,"leg":rules.leg,"outcome":rules.outcome}
	snapshot.rpc(state)
@rpc("authority","call_local","reliable",2)
func snapshot(state: Dictionary) -> void:
	wire = state
	if not multiplayer.is_server():
		rules.players = state.players
		rules.order.assign(state.order)
		rules.phase = state.phase
		rules.countdown = state.countdown
		rules.elapsed = state.elapsed
		rules.leg = state.leg
		rules.outcome = state.outcome
func apply_local_state() -> void:
	if not prepared or not local_id in rules.players: return
	var p: Dictionary = rules.players[local_id]
	if rules.phase in ["countdown","running"]:
		host.in_flight = true
		host.menu.hide()
		host.camera.current = true
		host.hud.show()
	var allowed := rules.can_fly(local_id)
	if rules.phase=="countdown" or (rules.phase=="running" and not allowed and p.result=="Waiting"):
		var attempted := Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_D)
		if local_input: attempted = host.joystick>=0 and (host.radio_axis(3)+1)/2>0.15
		if attempted: notify_event("False start before assigned relay turn")
	if allowed and last_turn!=rules.leg:
		host.remote_waiting_low = local_input
		host.low_throttle_time = 0
		last_turn = rules.leg
		if not local_input: host.active = true; host.drone.freeze = false
	if not allowed:
		host.active = false
		host.drone.freeze = true
		host.throttle = 0
	else:
		if not host.remote_waiting_low: host.active = true; host.drone.freeze = false
	if options.mode==1:
		host.next_gate = p.next
		host.section_index = p.section
		host.lap = p.lap
		host.minimap.visible = true
	else:
		host.minimap.hide()
		host.guide.hide()
		host.guidance.hide()
		var target: Vector3 = rules.stations()[mini(rules.leg+1,3)]
		overlay_marker.visible = true
		overlay_marker.position = target+Vector3.UP*2
		overlay_marker.text = "LZ %d · %.1f m" % [mini(rules.leg+1,3),host.drone.position.distance_to(target)]
		host.target_label.text = "TEAM RELAY · LEG %d/3 · %s" % [mini(rules.leg+1,3),"YOUR TURN" if allowed else "WAIT — THROTTLE LOW"]
	host.elapsed = rules.elapsed
	host.flight_status.text = "LAN %s · %s · Esc: withdraw/disconnect · V: attitude · no local pause/restart" % ["RELAY" if options.mode==0 else "OBSTACLE",p.result]
	if rules.phase=="countdown": host.status = "COUNTDOWN %.0f — keep throttle LOW" % ceil(rules.countdown)
	elif rules.phase=="running": host.status = "YOUR TURN — take off and land inside marked LZ" if allowed and options.mode==0 else "YOUR TURN — follow gates in order" if allowed else "WAIT for your relay turn. Moving launch controls early disqualifies the team."
	if rules.phase=="finished" or p.result in ["Finished","DQ"]:
		host.finished = true
		host.active = false
		host.drone.freeze = true
		host.status = rules.outcome if rules.phase=="finished" else "Your flight ended: "+p.result
		host.centre_panel.visible = true
		host.centre_label.text = host.status+"\nOpen LAN Competition for results / new round."
	if rules.phase!=last_phase:
		if rules.phase in ["running","finished"]: host.experience.tone(700 if rules.phase=="running" else 500,0.25)
		last_phase = rules.phase
func notify_event(reason: String) -> void:
	if not connected: return
	if multiplayer.is_server(): rules.disqualify(local_id,reason)
	else: race_event.rpc_id(1,reason)
@rpc("any_peer","call_remote","reliable",0)
func race_event(reason: String) -> void:
	if not multiplayer.is_server(): return
	if reason not in ["Crash","False start before assigned relay turn","Outside training area","Battery depleted — flight ended","Withdrawn / paused locally","USB radio disconnected"]: return
	rules.disqualify(multiplayer.get_remote_sender_id(),reason)
func refresh_board() -> void:
	var text := "TEAM RELAY" if options.mode==0 else "OBSTACLE RACE"
	text += " · "+rules.phase.to_upper()+(" · %.0f to start\n" % ceil(rules.countdown) if rules.phase=="countdown" else " · %.1fs\n" % rules.elapsed)
	if prepared and options.mode==0: text += "Next: LZ %d · %.1f m · diameter %.2f m\n" % [mini(rules.leg+1,3),host.drone.position.distance_to(rules.stations()[mini(rules.leg+1,3)]),options.radius*2]
	for i in range(rules.order.size()):
		var p: Dictionary = rules.players[rules.order[i]]
		text += "P%d %s · %s · %s\n" % [i+1,p.name,"READY" if p.ready else "NOT READY",p.result]
		update_ghost(rules.order[i],p,i)
	if options.mode==1 and rules.phase=="running":
		var rank := 1
		for row in rules.rows():
			text += "#%d %s · lap %d · gate %d · %s\n" % [rank,row.pilot,row.lap,row.gate,row.result]
			rank += 1
	if not rules.outcome.is_empty(): text += rules.outcome+"\n"
	if rules.phase=="finished":
		for row in rules.rows(): text += "%s · %.1fs · %s pts · %s\n" % [row.pilot,row.seconds,str(row.score),row.result]
		if not result_saved:
			result_saved = true
			save_result()
	if is_instance_valid(board): board.text = last_message+"\n\n"+text
	if is_instance_valid(race_board):
		race_board.visible = host.in_flight
		race_board.text = text
func update_ghost(id: int, p: Dictionary, index: int) -> void:
	if id==local_id or not is_instance_valid(room_world): return
	if not ghosts.has(id) or not is_instance_valid(ghosts[id]):
		var node := Node3D.new()
		room_world.add_child(node)
		var color: Color = [Color("55e5c0"),Color("ffa76d"),Color("94b9ff")][index%3]
		O.box(node,Vector3.ZERO,Vector3(p.span,0.06,p.span*0.2),color,false)
		O.box(node,Vector3.ZERO,Vector3(p.span*0.2,0.06,p.span),color,false)
		TERRAIN.label(node,"P%d %s" % [index+1,p.name],Vector3.UP*0.6,36)
		node.position = p.position
		ghosts[id] = node
	ghosts[id].position = ghosts[id].position.lerp(p.position,0.2)
	ghosts[id].rotation = Vector3(lerp_angle(ghosts[id].rotation.x,p.rotation.x,0.2),lerp_angle(ghosts[id].rotation.y,p.rotation.y,0.2),lerp_angle(ghosts[id].rotation.z,p.rotation.z,0.2))
func save_result() -> void:
	var file := FileAccess.open("user://lan-results.jsonl",FileAccess.READ_WRITE if FileAccess.file_exists("user://lan-results.jsonl") else FileAccess.WRITE)
	if not file: return
	file.seek_end()
	file.store_line(JSON.stringify({"timestamp":Time.get_datetime_string_from_system(),"mode":"Relay" if options.mode==0 else "Obstacle","terrain":["Mountain valley","Desert plain","City streets"][options.terrain],"outcome":rules.outcome,"seconds":rules.elapsed,"rules":options,"rows":rules.rows()}))
func history() -> Array:
	var rows: Array = []
	if not FileAccess.file_exists("user://lan-results.jsonl"): return rows
	var file := FileAccess.open("user://lan-results.jsonl",FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty(): continue
		var value = JSON.parse_string(line)
		if value is Dictionary and value.get("rows") is Array: rows.append(value)
	return rows
func show_history() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "LAN leaderboard — local history"
	var text := ""
	var records := history()
	for match_ in records.slice(maxi(0,records.size()-15)):
		text += "%s · %s · %.1fs · %s\n" % [match_.timestamp,match_.mode,match_.seconds,match_.outcome]
		for row in match_.rows: text += "  %s · %s · %.1fs · %s pts\n" % [row.pilot,row.result,row.seconds,str(row.score)]
	dialog.dialog_text = text if not text.is_empty() else "No completed LAN matches on this PC yet."
	host.add_child(dialog)
	dialog.popup_centered(Vector2i(900,500))
func export_csv() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.csv ; LAN results"])
	dialog.current_file = "lan-competition-results.csv"
	dialog.file_selected.connect(func(path): write_csv(path))
	host.add_child(dialog)
	dialog.popup_centered_ratio(0.7)
func write_csv(path: String) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if not file: return false
	file.store_csv_line(PackedStringArray(["timestamp","mode","terrain","outcome","pilot","result","seconds","score","reason"]))
	for match_ in history():
		for row in match_.rows:
			var values := PackedStringArray()
			for value in [match_.timestamp,match_.mode,match_.terrain,match_.outcome,row.pilot,row.result,row.seconds,row.score,row.get("reason","")]:
				var text := str(value)
				if text.strip_edges().begins_with("=") or text.strip_edges().begins_with("+") or text.strip_edges().begins_with("-") or text.strip_edges().begins_with("@"): text = "'"+text
				values.append(text)
			file.store_csv_line(values)
	return true
func disconnect_room(clear_message := true) -> void:
	if connected and local_id==1 and live():
		rules.disqualify(local_id,"Host ended room")
		save_result()
	connected = false
	connecting = false
	if multiplayer.has_multiplayer_peer(): multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	prepared = false
	ghosts.clear()
	if is_instance_valid(room_world): room_world.queue_free()
	if is_instance_valid(race_board): race_board.hide()
	host.leave_flight()
	if not backup.is_empty():
		host.course = backup.course
		for key in backup:
			if key!="course": host.set(key,backup[key])
		host.rebuild_course()
		host.gate_root.show()
		for item in host.solo_world_nodes:
			if is_instance_valid(item):
				if item is Node3D: item.show()
				if item is CollisionObject3D: item.collision_layer = 1
		backup.clear()
		host.experience.apply_weather()
		host.camera.far = 4000
		host.overview.far = 4000
	if clear_message: last_message = "Disconnected. Solo course, calibration and settings retained."
	host.status = last_message
	host.show_module("LAN Competition")

func save_room_preferences() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("room","options",options)
	cfg.set_value("room","address",address)
	cfg.set_value("room","port",port)
	cfg.save("user://lan-room.cfg")

func connection_fields() -> void:
	var ip := LineEdit.new()
	ip.text = address
	ip.placeholder_text = "Host local IPv4 address"
	ip.text_changed.connect(func(v): address = v.strip_edges())
	host.content.add_child(ip)
	host.field("UDP port",port,1024,65535,1,func(v): port = int(v))
	host.button_("HOST — create room",host_room,null,true)
	host.button_("JOIN — connect to host",join_room)
