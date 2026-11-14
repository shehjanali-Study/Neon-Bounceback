extends Node2D

const WALL := 26.0
const BR := 14.0
const TR := 17.0
const POW := 6.2
const MAX_S := 820.0
const MIN_S := 34.0
const DRAG := 90.0

const COL_C := Color("#2ef2ff")
const COL_P := Color("#ff2a9c")
const COL_PS := Color("#ff8ccb")
const COL_Y := Color("#ffd93d")
const COL_M := Color("#8ea2c4")
const DEFAULT_HINT := "1 SHOT ONLY • DRAG TO AIM"

@onready var arena: Panel = $Arena
@onready var lbl_title: Label = $HUD/Title
@onready var lbl_wave: Label = $HUD/Wave
@onready var lbl_score: Label = $HUD/Score
@onready var lbl_shots: Label = $HUD/Shots
@onready var lbl_hint: Label = $HUD/Hint

var W := 1152.0
var H := 648.0
var AX := 0.0
var AY := 0.0
var AW := 0.0
var AH := 0.0

var BL := 0.0
var BT := 0.0
var BRT := 0.0
var BBOT := 0.0
var CX := 0.0
var CY := 0.0

var ball_pos := Vector2.ZERO
var ball_vel := Vector2.ZERO
var ball_moving := false
var trail: Array[Vector2] = []
var aim_active := false
var aim_start := Vector2.ZERO
var aim_pull := Vector2.ZERO
var can_shoot := true
var score := 0
var score_bak := 0
var wave := 1
var fails := 0
var reset_timer := 0.0
var hard := false
var targets: Array = []
var targets_bak: Array = []
var particles: Array = []
var popups: Array = []
var hint_text := DEFAULT_HINT
var hint_timer := 0.0
var flash := 0.0
var shake := 0.0
var t := 0.0

func _ready() -> void:
	# Pull dimensions directly from the editable Arena Panel
	AX = arena.position.x
	AY = arena.position.y
	AW = arena.size.x
	AH = arena.size.y
	
	BL = AX + WALL / 2.0 + BR
	BT = AY + WALL / 2.0 + BR
	BRT = AX + AW - WALL / 2.0 - BR
	BBOT = AY + AH - WALL / 2.0 - BR
	CX = AX + AW / 2.0
	CY = AY + AH / 2.0
	
	start()

func start() -> void:
	score = 0
	score_bak = 0
	wave = 1
	fails = 0
	particles.clear()
	popups.clear()
	targets.clear()
	hint_text = DEFAULT_HINT
	hint_timer = 0.0
	reset_ball()
	spawn()

func reset_ball() -> void:
	ball_pos = Vector2(CX, CY)
	ball_vel = Vector2.ZERO
	ball_moving = false
	trail.clear()
	aim_active = false
	aim_pull = Vector2.ZERO
	can_shoot = true

func spawn() -> void:
	score_bak = score
	var tc := 2
	var hc := 0
	if wave == 1:
		tc = 2
	elif wave == 2:
		tc = 3
	elif wave == 3:
		tc = 2
		hc = 1
	else:
		tc = randi_range(3, 4)
		hc = 1
		
	targets.clear()
	for k in tc:
		var pt := Vector2(CX, CY)
		for i in 80:
			var p := Vector2(randf_range(AX + 84.0, AX + AW - 84.0), randf_range(AY + 84.0, AY + AH - 84.0))
			if p.distance_to(ball_pos) < 130.0:
				continue
			var too_close := false
			for tg in targets:
				if p.distance_to(tg.pos) < 100.0:
					too_close = true
					break
			if too_close:
				continue
			pt = p
			break
		var hp := 2 if k < hc else 1
		targets.append({"pos": pt, "hp": hp, "birth": t, "cd": 0.0})
	targets_bak = []
	for tg in targets:
		targets_bak.append(tg.duplicate())

func popup(pos: Vector2, txt: String, big := false, ok_pass := false) -> void:
	popups.append({"pos": pos, "life": -0.5 if big else 0.0, "text": txt, "big": big, "ok": ok_pass})

func hit(tg: Dictionary) -> bool:
	if tg.hp > 1:
		tg.hp -= 1
		popup(tg.pos, "HIT!")
		shake = 4.0
		for i in 8:
			particles.append({"pos": tg.pos, "vel": Vector2(randf_range(-150, 150), randf_range(-150, 150)),
				"life": 0.0, "life_max": randf_range(0.2, 0.4), "size": randf_range(1.0, 3.0), "color": Color.WHITE})
		var sp2 := ball_vel.length()
		if sp2 > 0.0:
			var ns := minf(sp2 * 1.1, MAX_S)
			ball_vel = ball_vel / sp2 * ns
		return false
		
	score += 100
	popup(tg.pos, "+100")
	for i in 22:
		var a := randf() * TAU
		var sp := randf_range(90.0, 320.0)
		var col := COL_P if randf() < 0.5 else COL_Y
		particles.append({"pos": tg.pos, "vel": Vector2(cos(a), sin(a)) * sp,
			"life": 0.0, "life_max": randf_range(0.35, 0.7), "size": randf_range(1.6, 3.4), "color": col})
	flash = 0.55
	shake = 7.0
	var sp2 := ball_vel.length()
	if sp2 > 0.0:
		var ns := minf(sp2 * 1.08, MAX_S)
		ball_vel = ball_vel / sp2 * ns
	return true

func update(dt: float) -> void:
	t += dt
	if flash > 0.0:
		flash = maxf(0.0, flash - dt * 2.4)
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 26.0)
	if hint_timer > 0.0:
		hint_timer -= dt
		if hint_timer <= 0.0:
			hint_text = DEFAULT_HINT
	if reset_timer > 0.0:
		reset_timer -= dt
		if reset_timer <= 0.0:
			reset_ball()
			if hard:
				hard = false
				spawn()

	if ball_moving:
		ball_pos += ball_vel * dt
		var bounced := false
		if ball_pos.x < BL:
			ball_pos.x = BL + (BL - ball_pos.x)
			ball_vel.x = absf(ball_vel.x)
			bounced = true
		elif ball_pos.x > BRT:
			ball_pos.x = BRT - (ball_pos.x - BRT)
			ball_vel.x = -absf(ball_vel.x)
			bounced = true
		if ball_pos.y < BT:
			ball_pos.y = BT + (BT - ball_pos.y)
			ball_vel.y = absf(ball_vel.y)
			bounced = true
		elif ball_pos.y > BBOT:
			ball_pos.y = BBOT - (ball_pos.y - BBOT)
			ball_vel.y = -absf(ball_vel.y)
			bounced = true
		if bounced:
			flash = maxf(flash, 0.16)

		var sp := ball_vel.length()
		var ns := maxf(0.0, sp - DRAG * dt)
		if sp > 0.0:
			ball_vel = ball_vel / sp * ns

		if trail.is_empty() or trail.back().distance_to(ball_pos) > 4.0:
			trail.append(ball_pos)
			if trail.size() > 18:
				trail.pop_front()

		var hit_any := false
		for i in range(targets.size() - 1, -1, -1):
			var tg: Dictionary = targets[i]
			if tg.cd > 0.0:
				tg.cd -= dt
			elif ball_pos.distance_to(tg.pos) < TR + BR:
				tg.cd = 0.15
				if hit(tg):
					targets.remove_at(i)
				hit_any = true

		if hit_any and targets.is_empty():
			hint_text = "NICE SHOT!"
			hint_timer = 2.0
			popup(Vector2(CX, CY - 60), "WAVE %d PASSED" % wave, true, true)
			wave += 1
			fails = 0
			reset_ball()
			spawn()
		elif ns <= MIN_S:
			ball_moving = false
			can_shoot = false
			ball_vel = Vector2.ZERO
			if not targets.is_empty():
				fails += 1
				if fails > 2:
					hint_text = "STRIKE 3 - BACK TO WAVE 1!"
					hint_timer = 2.0
					popup(Vector2(CX, CY - 60), "GAME OVER", true, false)
					reset_timer = 1.5
					wave = 1
					score = 0
					fails = 0
					hard = true
					targets.clear()
					shake = 20.0
				else:
					hint_text = "FAILED! RETRYING WAVE %d..." % wave
					hint_timer = 2.0
					score = score_bak
					targets = []
					for tg in targets_bak:
						targets.append(tg.duplicate())
					reset_timer = 1.2
					popup(Vector2(CX, CY - 60), "WAVE %d FAILED" % wave, true, false)
					shake = 15.0

	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life += dt
		if p.life >= p.life_max:
			particles.remove_at(i)
			continue
		p.pos += p.vel * dt
		p.vel *= 0.94

	for i in range(popups.size() - 1, -1, -1):
		popups[i].life += dt
		if popups[i].life > 0.8:
			popups.remove_at(i)

func _process(delta: float) -> void:
	update(minf(delta, 1.0 / 30.0))
	
	# Update HUD Labels
	lbl_wave.text = "WAVE: %d" % wave
	lbl_score.text = "SCORE  %06d" % score
	lbl_hint.text = hint_text
	if hint_timer > 0.0:
		lbl_hint.set("theme_override_colors/font_color", COL_PS)
	else:
		lbl_hint.set("theme_override_colors/font_color", COL_M)
		
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p := get_local_mouse_position()
		if event.pressed:
			press(p)
		else:
			release(p)
	elif event is InputEventMouseMotion and aim_active:
		update_aim(get_local_mouse_position())

func press(p: Vector2) -> void:
	if not can_shoot or ball_moving or aim_active:
		return
	if p.x < AX - 30 or p.x > AX + AW + 30 or p.y < AY - 30 or p.y > AY + AH + 30:
		return
	aim_active = true
	aim_start = p
	aim_pull = Vector2.ZERO

func update_aim(p: Vector2) -> void:
	var d := aim_start - p
	var l := d.length()
	if l > 130.0:
		d = d / l * 130.0
	aim_pull = d

func release(p: Vector2) -> void:
	if not aim_active:
		return
	update_aim(p)
	var l := aim_pull.length()
	if l < 16.0:
		aim_active = false
		aim_pull = Vector2.ZERO
		return
	var sp := minf(l * POW, MAX_S)
	ball_vel = aim_pull / l * sp
	ball_moving = true
	aim_active = false
	can_shoot = false
	aim_pull = Vector2.ZERO
	trail.clear()

# Draw transient effects: ball, targets, particles, popups, screen flash
func _draw() -> void:
	var sh := Vector2.ZERO
	if shake > 0.2:
		sh = Vector2(randf_range(-shake, shake), randf_range(-shake, shake)) * 0.5
	draw_set_transform(sh, 0.0, Vector2.ONE)

	# Draw ball trail
	var n := trail.size()
	for i in range(1, n):
		var k := float(i) / n
		draw_line(trail[i - 1], trail[i], Color(0.18, 0.95, 1.0, k * 0.42), 1.0 + k * 5.0, true)

	# Draw aim line
	var length := aim_pull.length()
	if aim_active and length >= 1.0:
		draw_line(ball_pos, ball_pos - aim_pull, Color(1.0, 0.165, 0.612, 0.85), 3.0)
		if length >= 16.0:
			var sp := minf(length * POW, MAX_S)
			var vel := aim_pull / length * sp
			var px := ball_pos.x
			var py := ball_pos.y
			var stp := 2.5 / 60.0
			for i in 85:
				px += vel.x * stp
				py += vel.y * stp
				if px < BL:
					px = BL + (BL - px)
					vel.x = absf(vel.x)
				elif px > BRT:
					px = BRT - (px - BRT)
					vel.x = -absf(vel.x)
				if py < BT:
					py = BT + (BT - py)
					vel.y = absf(vel.y)
				elif py > BBOT:
					py = BBOT - (py - BBOT)
					vel.y = -absf(vel.y)
				var a := 0.8 * (1.0 - float(i) / 84.0 * 0.85)
				draw_circle(Vector2(px, py), 3.2 - float(i) / 84.0 * 2.0, Color(COL_C.r, COL_C.g, COL_C.b, a))

	# Draw targets
	for tg in targets:
		var pls := 1.0 + sin((t - tg.birth) * 4.0) * 0.07
		var ring_col := Color(1, 1, 1, 0.6) if tg.hp > 1 else Color(COL_PS.r, COL_PS.g, COL_PS.b, 0.6)
		draw_arc(tg.pos, 22.0 * pls, 0.0, TAU, 32, ring_col, 3.0)
		if tg.hp > 1:
			draw_arc(tg.pos, 14.0 * pls, 0.0, TAU, 24, COL_C, 2.0)
		var r := 6.0 * pls
		var center_col := COL_P if tg.hp > 1 else COL_Y
		center_col.a = 0.9
		var pos: Vector2 = tg.pos
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -r), pos + Vector2(r, 0), pos + Vector2(0, r), pos + Vector2(-r, 0)]), center_col)

	# Draw particles
	for p in particles:
		var a: float = 1.0 - p.life / p.life_max
		var sz: float = p.size
		var c: Color = p.color
		draw_rect(Rect2(p.pos - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), Color(c.r, c.g, c.b, a))

	# Draw ball glow and core
	for i in 8:
		draw_circle(ball_pos, 40.0 - i * 5.0, Color(0.18, 0.95, 1.0, 0.07))
	draw_circle(ball_pos, BR, COL_C)
	var d := 5.0
	draw_colored_polygon(PackedVector2Array([ball_pos + Vector2(0, -d), ball_pos + Vector2(d, 0), ball_pos + Vector2(0, d), ball_pos + Vector2(-d, 0)]), Color(0.92, 1.0, 1.0, 0.95))

	# Draw transient popups
	for p in popups:
		var k := maxf(0.0, p.life / 0.8)
		var col: Color = COL_Y
		if p.big:
			col = Color("#20ff70") if p.ok else COL_P
		col.a = 1.0 - k
		var size := 48 if p.big else 20
		# Draw center-aligned string manually for popups to stay decoupled from UI nodes
		var font = ThemeDB.fallback_font
		var str_size = font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		draw_string(font, Vector2(p.pos.x - str_size.x / 2.0, p.pos.y - 34.0 - k * 46.0), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

	# Draw screen flash overlay
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(1.0, 0.314, 0.667, flash * 0.07))
