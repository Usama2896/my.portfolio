extends SceneTree
const RULES = preload("res://competition_rules.gd")
var checks := 0
func check(condition: bool, title: String) -> void:
	assert(condition,title)
	checks += 1
func team():
	var r = RULES.new()
	for id in [1,2,3]:
		r.add_player(id,"Pilot "+str(id),0.3)
		r.players[id].ready = true
	return r
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var r = team()
	check(r.stations()[1]==Vector3(-50,0,0) and r.stations()[3]==Vector3(0,0,-50),"three ordered legs")
	check(r.begin(),"three ready pilots start")
	check(not r.can_fly(1),"countdown gates flight")
	r.tick(5.1)
	check(r.can_fly(1) and not r.can_fly(2),"only first relay pilot takes off")
	for index in range(3):
		var id := index+1
		var target: Vector3 = r.stations()[index+1]
		r.report(id,r.stations()[index]+Vector3.UP,Vector3.ZERO,Vector3.ZERO)
		r.tick(0.1)
		r.report(id,target+Vector3.UP*0.15,Vector3.ZERO,Vector3.ZERO)
		r.tick(0.5)
		check(r.leg==index,"touch without hold does not hand off")
		r.tick(0.55)
		check(r.players[id].result=="Finished","settled centred landing accepted")
		check(r.leg==index+1,"one leg advanced")
	check(r.phase=="finished" and r.players[1].score>=200,"all three landings finish with team score")
	check(r.players[1].score==r.players[3].score,"one shared relay score")
	r = team()
	r.players[3].ready = false
	check(not r.begin(),"unready pilot blocks countdown")
	r.players[3].ready = true
	r.players[3].span = 0.8
	check(not r.begin(),"oversized drone cannot fit default LZ")
	r = team()
	r.begin()
	r.disqualify(2,"False start")
	check(r.phase=="finished" and r.outcome.contains("False start"),"false start disqualifies team")
	r = team()
	r.begin()
	r.tick(5)
	r.report(1,Vector3(0,1,0),Vector3.ZERO,Vector3.ZERO)
	r.tick(0.1)
	r.report(1,Vector3(-49.6,0.15,0),Vector3.ZERO,Vector3.ZERO)
	r.tick(1.1)
	check(r.outcome.contains("outside"),"body outside landing-zone edge rejected")
	r = team()
	r.begin()
	r.tick(5)
	r.disqualify(1,"Crash")
	check(r.outcome.contains("Crash"),"crash disqualifies whole relay")
	r = team()
	r.begin()
	r.tick(5)
	r.tick(241)
	check(r.phase=="finished" and r.outcome.contains("Maximum"),"maximum shared time enforced")
	r = team()
	for time_ in [175.0,180.0,184.9,185.0]:
		r.elapsed = time_
		check(r.time_points()==[1,0,0,-1][[175.0,180.0,184.9,185.0].find(time_)],"full five-second time adjustment")
	r.options.legs = [30.0,1000.0,5000.0]
	check(r.stations()[3]==Vector3(4970,0,-1000),"independent distances to five kilometres")
	r = team()
	r.options.mode = 1
	r.players.erase(3)
	r.order.erase(3)
	r.course = {"laps":1,"gates":[{"type":"ring","x":0.0,"z":-4.0,"height":2.0,"width":2.0,"opening_height":2.0,"depth":1.0,"yaw_degrees":0.0}]}
	r.report(1,Vector3(0,2,-3),Vector3.ZERO,Vector3.ZERO)
	check(r.begin(),"two-player obstacle start")
	r.tick(5)
	check(r.can_fly(1) and r.can_fly(2),"both racers fly simultaneously")
	r.report(1,Vector3(0,2,-5),Vector3.ZERO,Vector3.ZERO)
	check(r.players[1].result=="Finished","host validates directional gate crossing")
	r.disqualify(2,"Crash")
	check(r.players[1].result=="Finished" and r.phase=="finished","opponent crash does not invalidate winner")
	var nan_position := Vector3(NAN,0,0)
	r.report(2,nan_position,Vector3.ZERO,Vector3.ZERO)
	check(r.players[2].position.is_finite(),"nonfinite telemetry ignored")
	r = team()
	r.options.mode = 1
	r.players[1].lap = 1
	r.players[1].next = 10
	r.players[2].lap = 2
	r.players[2].next = 0
	r.players[3].result = "DQ"
	check(r.rows()[0].id==2 and r.rows()[2].id==3,"live leaderboard prioritizes lap and puts DQ last")
	print("PASS: ",checks," relay, scoring, distance and competitive-course rule checks")
	quit()
