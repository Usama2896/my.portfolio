extends RefCounted
const O = preload("res://obstacles.gd")
var options := {"mode":0,"terrain":0,"legs":[50.0,50.0,50.0],"radius":0.3048,"settle":1.0,"qualifying":180.0,"maximum":240.0,"controls":1,"base":100,"landing_bonus":100}
var players: Dictionary = {}
var order: Array[int] = []
var phase := "lobby"
var countdown := 0.0
var elapsed := 0.0
var leg := 0
var outcome := ""
var course: Dictionary = {}
func stations() -> Array[Vector3]:
	return [Vector3.ZERO,Vector3(-options.legs[0],0,0),Vector3(-options.legs[0],0,-options.legs[1]),Vector3(-options.legs[0]+options.legs[2],0,-options.legs[1])]
func add_player(id: int, title: String, span: float) -> void:
	players[id] = {"name":title.strip_edges().left(40) if not title.strip_edges().is_empty() else "Guest","span":clampf(span,0.1,1.4),"ready":false,"position":Vector3.ZERO,"rotation":Vector3.ZERO,"velocity":Vector3.ZERO,"seen":0.0,"launched":false,"hold":0.0,"outside":0.0,"next":0,"section":0,"lap":1,"result":"Waiting","time":0.0,"score":0,"last":Vector3.ZERO}
	if not id in order: order.append(id)
func begin() -> bool:
	if phase not in ["lobby","finished"]: return false
	if order.size()<2 or (options.mode==0 and order.size()!=3): return false
	for id in order:
		if not players[id].ready: return false
		if options.mode==0 and players[id].span>=options.radius*2: return false
	phase = "countdown"
	countdown = 5
	elapsed = 0
	leg = 0
	outcome = ""
	for id in order:
		var p: Dictionary = players[id]
		p.erase("reason")
		p.seen = 0.0
		p.launched = false
		p.hold = 0.0
		p.outside = 0.0
		p.next = 0
		p.section = 0
		p.lap = 1
		p.result = "Waiting"
		p.time = 0.0
		p.score = 0
	return true
func can_fly(id: int) -> bool:
	return phase=="running" and id in players and players[id].result not in ["Finished","DQ"] and (options.mode==1 or (leg<order.size() and order[leg]==id))
func disqualify(id: int, reason: String) -> void:
	if phase not in ["countdown","running"] or not id in players: return
	if players[id].result=="DQ" or (options.mode==1 and players[id].result=="Finished"): return
	players[id].result = "DQ"
	players[id].reason = reason
	players[id].time = elapsed
	if options.mode==0:
		phase = "finished"
		outcome = "TEAM DQ — "+reason
	else:
		var pending := false
		for peer in order:
			if players[peer].result not in ["Finished","DQ"]: pending = true
		if not pending: phase = "finished"; outcome = "Obstacle race complete"
func report(id: int, position_: Vector3, rotation_: Vector3, velocity_: Vector3) -> void:
	if not id in players or not position_.is_finite() or not rotation_.is_finite() or not velocity_.is_finite(): return
	var p: Dictionary = players[id]
	p.seen = 0.0
	p.rotation = rotation_
	p.velocity = velocity_
	var previous: Vector3 = p.position
	p.position = position_
	if phase=="running" and can_fly(id) and options.mode==1: cross_gates(id,previous,position_)
func tick(delta: float) -> void:
	if phase=="countdown":
		countdown -= delta
		if countdown<=0:
			phase = "running"
			for id in order: players[id].result = "Flying" if can_fly(id) else "Waiting"
		return
	if phase!="running": return
	elapsed += delta
	if elapsed>options.maximum:
		for id in order:
			if players[id].result not in ["Finished","DQ"]: disqualify(id,"Maximum time exceeded")
		return
	for id in order:
		var p: Dictionary = players[id]
		p.seen += delta
		if p.seen>4 and p.result not in ["Finished","DQ"]: disqualify(id,"Pilot connection/telemetry lost"); return
		if not can_fly(id): continue
		var pos: Vector3 = p.position
		if pos.y>p.span/2+0.20: p.launched = true
		if options.mode!=0 or not p.launched: continue
		var ground: bool = pos.y<=p.span/2+0.13
		var target: Vector3 = stations()[leg+1]
		var centered: bool = Vector2(pos.x-target.x,pos.z-target.z).length()+p.span/2<=options.radius
		var level := Basis.from_euler(p.rotation).y.dot(Vector3.UP)>0.9
		var settled: bool = ground and p.velocity.length()<=0.6 and level
		p.hold = p.hold+delta if settled and centered else 0.0
		p.outside = p.outside+delta if settled and not centered else 0.0
		if p.outside>=options.settle: disqualify(id,"Landing outside designated LZ"); return
		if p.hold>=options.settle:
			p.result = "Finished"
			p.time = elapsed
			leg += 1
			if leg==3:
				phase = "finished"
				outcome = "RELAY COMPLETE — all three pilots landed"
				var score := maxi(0,int(options.base)+int(options.landing_bonus if elapsed<=options.qualifying else 0)+time_points())
				for peer in order: players[peer].score = score
				return
			players[order[leg]].result = "Flying"
func cross_gates(id: int, from: Vector3, to: Vector3) -> void:
	if course.is_empty(): return
	var p: Dictionary = players[id]
	var data: Dictionary = course.gates[p.next]
	var rotation_ := Vector3(deg_to_rad(float(data.get("pitch_degrees",0))),deg_to_rad(float(data.yaw_degrees)),deg_to_rad(float(data.get("roll_degrees",0))))
	if data.type=="dive": rotation_.x -= PI/2
	var transform_ := Transform3D(Basis.from_euler(rotation_),Vector3(data.x,data.height,data.z))
	var a_local := transform_.affine_inverse()*from
	var b_local := transform_.affine_inverse()*to
	var sections := O.sections(data)
	for unused in range(sections.size()):
		var section: Dictionary = sections[p.section]
		var basis_: Basis = section.get("basis",Basis.IDENTITY)
		var a: Vector3 = basis_.inverse()*(a_local-section.center)
		var b: Vector3 = basis_.inverse()*(b_local-section.center)
		if not (a.z>0 and b.z<=0): break
		var point := a_local.lerp(b_local,a.z/(a.z-b.z))
		if not O.fits(data,point,p.section,p.span/2): break
		p.section += 1
		if p.section==sections.size():
			p.section = 0
			p.next += 1
			if p.next==course.gates.size():
				p.next = 0
				if p.lap==int(course.laps):
					p.result = "Finished"
					p.time = elapsed
					p.score = maxi(0,int(options.base)+time_points())
					var all_done := true
					for peer in order:
						if players[peer].result not in ["Finished","DQ"]: all_done = false
					if all_done: phase = "finished"; outcome = "Obstacle race complete"
				else: p.lap += 1
			break
func rows() -> Array:
	var result: Array = []
	for id in order:
		var p: Dictionary = players[id]
		result.append({"id":id,"pilot":p.name,"result":p.result,"seconds":snappedf(p.time if p.time>0 else elapsed,0.01),"score":p.score,"gate":p.next+1,"lap":p.lap,"section":p.section,"reason":p.get("reason","")})
	result.sort_custom(func(a,b):
		var a_status := 0 if a.result=="Finished" else 2 if a.result=="DQ" else 1
		var b_status := 0 if b.result=="Finished" else 2 if b.result=="DQ" else 1
		if a_status!=b_status: return a_status<b_status
		if a.result=="Finished" and b.result=="Finished": return a.seconds<b.seconds
		if a.lap!=b.lap: return a.lap>b.lap
		if a.gate!=b.gate: return a.gate>b.gate
		if a.section!=b.section: return a.section>b.section
		return a.id<b.id)
	return result

func time_points() -> int:
	var difference: float = options.qualifying-elapsed
	return int(floor(absf(difference)/5))*(1 if difference>=0 else -1)
