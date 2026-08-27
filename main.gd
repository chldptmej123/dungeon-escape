extends Node2D

const TILE := 48
const MAP := [
	"####################",
	"#........D.........#",
	"#.######...######..#",
	"#.#....#...#....#..#",
	"#.#.##.#####.##.#..#",
	"#...##.......##....#",
	"###.########.#######",
	"#....#......#......#",
	"#.##.#.####.#.####.#",
	"#.#..#....#.#....#.#",
	"#.######.#.######..#",
	"#..................#",
	"####################"
]

var player := Vector2(2.5, 1.5) * TILE
var key_pos := Vector2(7.5, 5.5) * TILE
var portal_pos := Vector2(16.5, 2.5) * TILE
var enemy_pos := Vector2(3.5, 9.5) * TILE
var has_key := false
var enemy_alive := true
var health := 100.0
var swing := 0.0
var cooldown := 0.0
var won := false
var dead := false

func _process(delta: float) -> void:
	if (won or dead) and Input.is_key_pressed(KEY_R):
		reset_level()
		return
	if won or dead:
		queue_redraw()
		return

	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
	move = move.normalized() * 190.0 * delta
	try_move(Vector2(move.x, 0))
	try_move(Vector2(0, move.y))

	cooldown = maxf(0.0, cooldown - delta)
	swing = maxf(0.0, swing - delta)
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)) and cooldown <= 0.0:
		cooldown = 0.34
		swing = 0.22
		if enemy_alive and player.distance_to(enemy_pos) < 88.0:
			enemy_alive = false

	if not has_key and player.distance_to(key_pos) < 30.0:
		has_key = true
	# The visible portal is wide, so its interaction range should be forgiving too.
	if has_key and player.distance_to(portal_pos) < 70.0:
		won = true

	if enemy_alive:
		var to_player := player - enemy_pos
		if to_player.length() < 240.0:
			enemy_pos += to_player.normalized() * 55.0 * delta
		if player.distance_to(enemy_pos) < 38.0:
			health -= 25.0 * delta
			if health <= 0.0: dead = true
	queue_redraw()

func try_move(amount: Vector2) -> void:
	var candidate := player + amount
	var corners := [Vector2(-14,-14), Vector2(14,-14), Vector2(-14,14), Vector2(14,14)]
	for corner in corners:
		if solid_at(candidate + corner): return
	player = candidate

func solid_at(point: Vector2) -> bool:
	var tx := int(point.x / TILE)
	var ty := int(point.y / TILE)
	if ty < 0 or ty >= MAP.size() or tx < 0 or tx >= MAP[ty].length(): return true
	var tile: String = MAP[ty][tx]
	return tile == "#" or (tile == "D" and not has_key)

func reset_level() -> void:
	player = Vector2(2.5, 1.5) * TILE
	enemy_pos = Vector2(3.5, 9.5) * TILE
	has_key = false
	enemy_alive = true
	health = 100.0
	won = false
	dead = false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 672)), Color("141812"))
	for y in MAP.size():
		for x in MAP[y].length():
			var pos := Vector2(x, y) * TILE
			var tile: String = MAP[y][x]
			if tile == "#": draw_stone_wall(pos, x, y)
			elif tile == "D" and not has_key:
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color("76501f"))
				draw_rect(Rect2(pos + Vector2(5,5), Vector2(TILE-10, TILE-10)), Color("bd9138"), false, 3)
				draw_circle(pos + Vector2(TILE/2, TILE/2), 6, Color("f5d46d"))
			else:
				draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color("39352d"))
				draw_line(pos, pos + Vector2(TILE, TILE), Color("49443a"), 1)
				draw_line(pos + Vector2(TILE, 0), pos + Vector2(0, TILE), Color("49443a"), 1)

	if not has_key:
		draw_circle(key_pos, 13, Color("f5d35b"))
		draw_rect(Rect2(key_pos + Vector2(7,-4), Vector2(22,8)), Color("f5d35b"))
		draw_circle(key_pos + Vector2(28,0), 5, Color("342c1c"))

	var portal_color := Color("49d9f1") if has_key else Color("4b5263")
	draw_circle(portal_pos, 28, Color(portal_color.r, portal_color.g, portal_color.b, 0.22))
	draw_circle(portal_pos, 19, portal_color, false, 3)
	draw_circle(portal_pos, 10, Color("d6fbff") if has_key else Color("777d89"))

	if enemy_alive:
		draw_circle(enemy_pos, 17, Color("a72d2d"))
		draw_circle(enemy_pos + Vector2(-6,-3), 4, Color("ffd75a"))
		draw_circle(enemy_pos + Vector2(6,-3), 4, Color("ffd75a"))

	var aim := (get_viewport().get_mouse_position() - player).normalized()
	if aim == Vector2.ZERO: aim = Vector2.RIGHT
	var angle := aim.angle()
	if swing > 0.0: angle += sin((1.0 - swing/0.22) * PI) * 1.25
	draw_circle(player, 16, Color("d8e7e1"))
	draw_circle(player + Vector2(cos(angle), sin(angle)) * 5, 4, Color("304c5b"))
	var blade_start := player + Vector2(cos(angle), sin(angle)) * 15
	var blade_end := player + Vector2(cos(angle), sin(angle)) * 55
	draw_line(blade_start, blade_end, Color("d8e2e4"), 8)
	draw_line(blade_start, blade_end, Color("7d9299"), 2)
	var guard := Vector2(-sin(angle), cos(angle)) * 12
	draw_line(blade_start - guard, blade_start + guard, Color("c5a253"), 5)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(20, 28), "HEALTH %03d" % int(maxf(0, health)), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	draw_string(font, Vector2(20, 54), "GOLD KEY: PORTAL ACTIVE" if has_key else "FIND THE GOLD KEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f5d35b") if has_key else Color("d9d8cf"))
	draw_string(font, Vector2(20, 650), "WASD move  |  click / Space: sword  |  R: restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d9d8cf"))
	if won or dead:
		var message := "YOU ESCAPED — press R" if won else "YOU DIED — press R"
		draw_rect(Rect2(210, 280, 540, 78), Color(0,0,0,0.7))
		draw_string(font, Vector2(285, 330), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

func draw_stone_wall(pos: Vector2, x: int, y: int) -> void:
	var tint := 0.72 + float((x * 13 + y * 7) % 15) / 100.0
	draw_rect(Rect2(pos, Vector2(TILE, TILE)), Color(0.36*tint, 0.38*tint, 0.31*tint))
	draw_rect(Rect2(pos + Vector2(3,3), Vector2(TILE-6, TILE-6)), Color(0.47*tint, 0.49*tint, 0.40*tint))
	draw_line(pos + Vector2(4, TILE-5), pos + Vector2(TILE-5, TILE-5), Color("252820"), 2)
	draw_line(pos + Vector2(TILE-5, 4), pos + Vector2(TILE-5, TILE-5), Color("252820"), 2)
