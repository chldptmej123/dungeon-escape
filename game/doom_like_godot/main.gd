extends Node3D

const CELL: float = 3.2
const WALL_HEIGHT: float = 3.2
const MAX_HEALTH: float = 50.0
const SWORD_DAMAGE: float = 12.0
const BOSS_HITS_TO_DEFEAT: int = 5
const BOSS_HEALTH: float = SWORD_DAMAGE * BOSS_HITS_TO_DEFEAT
const MAP_ONE: Array[String] = [
	"############",
	"#..........#",
	"#.####.###.#",
	"#....#.....#",
	"####.#.###.#",
	"#....#...#.#",
	"#.######.#.#",
	"#..........#",
	"############"
]
const MAP_TWO: Array[String] = [
	"################",
	"#....#.........#",
	"#.##.#.#######.#",
	"#..........#...#",
	"####.#####.#.###",
	"#....#.....#...#",
	"#.##.#####.###.#",
	"#....#.........#",
	"####.#####.##..#",
	"#......#...#...#",
	"#.####.#.#####.#",
	"################"
]

var player: CharacterBody3D
var camera: Camera3D
var sword: Node3D
var enemies: Array[Node3D] = []
var clown_projectiles: Array[CharacterBody3D] = []
var health: float = MAX_HEALTH
var damage_cooldown: float = 0.0
var damage_audio: AudioStreamPlayer
var damage_playback: AudioStreamGeneratorPlayback
var footstep_audio: AudioStreamPlayer
var footstep_playback: AudioStreamGeneratorPlayback
var sword_audio: AudioStreamPlayer
var sword_playback: AudioStreamGeneratorPlayback
var world_sfx_audio: AudioStreamPlayer
var world_sfx_playback: AudioStreamGeneratorPlayback
var enemy_sfx_audio: AudioStreamPlayer
var enemy_sfx_playback: AudioStreamGeneratorPlayback
var ghost_cue_timer: float = 0.0
var footstep_timer: float = 0.0
var swing_time: float = 0.0
var swing_cooldown: float = 0.0
const SWING_DURATION: float = 0.34
const WALK_SPEED: float = 2.8
const SPRINT_SPEED: float = 5.2
const FLY_SPEED: float = 4.2
var yaw: float = 0.0
var pitch: float = 0.0
var jump_was_pressed: bool = false
var fly_mode: bool = false
var status: Label
var heart_fill: Label
var restart_button: Button
var wall_material: StandardMaterial3D
var hurt_overlay: ColorRect
var damage_flash: float = 0.0
var game_over: bool = false
var game_won: bool = false
var outcome_label: Label
var world_root: Node3D
var active_map: Array[String] = MAP_ONE
var map_index: int = 0
var portal_position: Vector3 = Vector3.ZERO
var portal_active: bool = false
var portal_dismissed: bool = false
const PORTAL_TRIGGER_DISTANCE: float = 2.1
const PORTAL_REARM_DISTANCE: float = 2.6
var portal_prompt: PanelContainer
var health_pickup: Node3D
var health_pickup_base_position: Vector3 = Vector3.ZERO
var health_pickup_active: bool = false
var traps: Array[Node3D] = []
var wall_traps: Array[Node3D] = []
var sword_owned: bool = false
var sword_chest: Node3D
var sword_chest_lid: MeshInstance3D
var sword_chest_lock: MeshInstance3D
var sword_chest_position: Vector3 = Vector3.ZERO
var sword_chest_active: bool = false
var weapon_prompt: Label
var weapon_choice: String = ""
var choice_chests: Array[Node3D] = []
var magic_glove: Node3D
var magic_balls: Array[CharacterBody3D] = []
var magic_cooldown: float = 0.0
var magic_reticle: Label
var map_two_bgm_audio: AudioStreamPlayer
var map_two_bgm_playback: AudioStreamGeneratorPlayback
var map_two_drip_audio: AudioStreamPlayer
var map_two_drip_playback: AudioStreamGeneratorPlayback
var map_two_bgm_phase: float = 0.0
var map_two_drip_timer: float = 0.0
var ambience_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	ambience_rng.randomize()
	wall_material = dungeon_wall_material()
	world_root = Node3D.new()
	add_child(world_root)
	build_dungeon()
	create_player()
	create_hud()
	create_damage_audio()
	create_action_audio()
	create_extra_sfx_audio()
	create_map_two_ambience_audio()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func create_damage_audio() -> void:
	damage_audio = AudioStreamPlayer.new()
	var damage_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	damage_stream.mix_rate = 22050.0
	damage_stream.buffer_length = 0.25
	damage_audio.stream = damage_stream
	damage_audio.volume_db = -7.0
	add_child(damage_audio)
	damage_audio.play()
	damage_playback = damage_audio.get_stream_playback() as AudioStreamGeneratorPlayback

func play_damage_tone() -> void:
	if damage_playback == null:
		return
	var frames: int = mini(2425, damage_playback.get_frames_available())
	for frame_index in range(frames):
		var progress: float = float(frame_index) / float(frames)
		var sample: float = sin(TAU * 185.0 * float(frame_index) / 22050.0) * 0.22 * (1.0 - progress)
		damage_playback.push_frame(Vector2(sample, sample))

func create_action_audio() -> void:
	footstep_audio = AudioStreamPlayer.new()
	var footstep_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	footstep_stream.mix_rate = 22050.0
	footstep_stream.buffer_length = 0.32
	footstep_audio.stream = footstep_stream
	footstep_audio.volume_db = -7.5
	add_child(footstep_audio)
	footstep_audio.play()
	footstep_playback = footstep_audio.get_stream_playback() as AudioStreamGeneratorPlayback

	sword_audio = AudioStreamPlayer.new()
	var sword_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	sword_stream.mix_rate = 22050.0
	sword_stream.buffer_length = 0.25
	sword_audio.stream = sword_stream
	sword_audio.volume_db = -11.0
	add_child(sword_audio)
	sword_audio.play()
	sword_playback = sword_audio.get_stream_playback() as AudioStreamGeneratorPlayback

func create_extra_sfx_audio() -> void:
	# Shared scene-root channels prevent map rebuilds from duplicating short SFX players.
	world_sfx_audio = AudioStreamPlayer.new()
	var world_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	world_stream.mix_rate = 22050.0
	world_stream.buffer_length = 0.35
	world_sfx_audio.stream = world_stream
	world_sfx_audio.volume_db = -13.0
	add_child(world_sfx_audio)
	world_sfx_audio.play()
	world_sfx_playback = world_sfx_audio.get_stream_playback() as AudioStreamGeneratorPlayback

	enemy_sfx_audio = AudioStreamPlayer.new()
	var enemy_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	enemy_stream.mix_rate = 22050.0
	enemy_stream.buffer_length = 0.30
	enemy_sfx_audio.stream = enemy_stream
	enemy_sfx_audio.volume_db = -16.0
	add_child(enemy_sfx_audio)
	enemy_sfx_audio.play()
	enemy_sfx_playback = enemy_sfx_audio.get_stream_playback() as AudioStreamGeneratorPlayback

func play_world_sfx(kind: String) -> void:
	if world_sfx_playback == null:
		return
	var frames: int = mini(2600, world_sfx_playback.get_frames_available())
	for frame_index in range(frames):
		var time: float = float(frame_index) / 22050.0
		var sample: float = 0.0
		if kind == "equip":
			sample = (sin(TAU * (420.0 + 780.0 * time) * time) * 0.18 + sin(TAU * 780.0 * time) * 0.08) * exp(-time * 8.0)
		elif kind == "heart":
			sample = (sin(TAU * 640.0 * time) * 0.14 + sin(TAU * 960.0 * time) * 0.07) * exp(-time * 10.0)
		elif kind == "trap":
			sample = (sin(TAU * 74.0 * time) * 0.24 + sin(TAU * 440.0 * time) * 0.08) * exp(-time * 14.0)
		elif kind == "portal":
			sample = (sin(TAU * (120.0 + 260.0 * time) * time) * 0.14 + sin(TAU * 300.0 * time) * 0.05) * exp(-time * 5.0)
		world_sfx_playback.push_frame(Vector2(sample, sample))

func play_enemy_sfx(kind: String) -> void:
	if enemy_sfx_playback == null:
		return
	var frames: int = mini(2100, enemy_sfx_playback.get_frames_available())
	for frame_index in range(frames):
		var time: float = float(frame_index) / 22050.0
		var sample: float = 0.0
		if kind == "blade_hit":
			sample = (sin(TAU * 185.0 * time) * 0.18 + sin(TAU * 920.0 * time) * 0.075) * exp(-time * 24.0)
		elif kind == "volley":
			sample = (sin(TAU * (320.0 + 950.0 * time) * time) * 0.12 + sin(TAU * 780.0 * time) * 0.05) * exp(-time * 13.0)
		elif kind == "impact":
			sample = (sin(TAU * 120.0 * time) * 0.18 + sin(TAU * 1160.0 * time) * 0.045) * exp(-time * 30.0)
		elif kind == "ghost":
			sample = (sin(TAU * 92.0 * time) * 0.05 + sin(TAU * 137.0 * time) * 0.026) * sin(TAU * 3.0 * time) * exp(-time * 3.8)
		enemy_sfx_playback.push_frame(Vector2(sample, sample))

func create_map_two_ambience_audio() -> void:
	# These players belong to the scene root and are created once, never per map rebuild.
	map_two_bgm_audio = AudioStreamPlayer.new()
	var bgm_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	bgm_stream.mix_rate = 22050.0
	bgm_stream.buffer_length = 0.5
	map_two_bgm_audio.stream = bgm_stream
	map_two_bgm_audio.volume_db = -20.5
	add_child(map_two_bgm_audio)

	map_two_drip_audio = AudioStreamPlayer.new()
	var drip_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	drip_stream.mix_rate = 22050.0
	drip_stream.buffer_length = 0.35
	map_two_drip_audio.stream = drip_stream
	map_two_drip_audio.volume_db = -18.0
	add_child(map_two_drip_audio)

func set_map_two_ambience(enabled: bool) -> void:
	if enabled:
		if not map_two_bgm_audio.playing:
			map_two_bgm_phase = 0.0
			map_two_bgm_audio.play()
			map_two_bgm_playback = map_two_bgm_audio.get_stream_playback() as AudioStreamGeneratorPlayback
		if not map_two_drip_audio.playing:
			map_two_drip_audio.play()
			map_two_drip_playback = map_two_drip_audio.get_stream_playback() as AudioStreamGeneratorPlayback
			map_two_drip_timer = ambience_rng.randf_range(1.4, 3.0)
	else:
		if map_two_bgm_audio.playing:
			map_two_bgm_audio.stop()
		if map_two_drip_audio.playing:
			map_two_drip_audio.stop()
		map_two_bgm_playback = null
		map_two_drip_playback = null

func update_map_two_ambience(delta: float) -> void:
	if map_index != 1 or map_two_bgm_playback == null:
		return
	var frames: int = mini(2048, map_two_bgm_playback.get_frames_available())
	for frame_index in range(frames):
		var time: float = map_two_bgm_phase / 22050.0
		var pulse: float = 0.68 + sin(TAU * 0.09 * time) * 0.24
		var low_drone: float = sin(TAU * 43.65 * time) * 0.070 + sin(TAU * 65.41 * time) * 0.032
		var discord: float = sin(TAU * 92.50 * time) * 0.014 + sin(TAU * 103.83 * time) * 0.011
		var wind: float = (sin(TAU * 311.0 * time) + sin(TAU * 487.0 * time) * 0.55 + sin(TAU * 719.0 * time) * 0.25) * sin(TAU * 0.17 * time) * 0.006
		var space: float = sin(TAU * 0.031 * time) * sin(TAU * 174.61 * time) * 0.010
		var sample: float = (low_drone + discord + wind + space) * pulse
		map_two_bgm_playback.push_frame(Vector2(sample, sample))
		map_two_bgm_phase += 1.0
	map_two_drip_timer -= delta
	if map_two_drip_timer <= 0.0:
		play_map_two_drip()
		map_two_drip_timer = ambience_rng.randf_range(2.6, 6.8)

func play_map_two_drip() -> void:
	if map_two_drip_playback == null:
		return
	var frames: int = mini(3000, map_two_drip_playback.get_frames_available())
	var drop_pitch: float = ambience_rng.randf_range(720.0, 1260.0)
	var echo_delay: float = ambience_rng.randf_range(0.045, 0.085)
	for frame_index in range(frames):
		var time: float = float(frame_index) / 22050.0
		var impact: float = sin(TAU * (drop_pitch - 430.0 * time) * time) * exp(-time * 46.0) * 0.14
		var stone_tick: float = sin(TAU * (drop_pitch * 1.8) * time) * exp(-time * 82.0) * 0.035
		var cavern_time: float = maxf(0.0, time - echo_delay)
		var cavern_echo: float = sin(TAU * 108.0 * cavern_time) * exp(-cavern_time * 13.0) * 0.042
		var sample: float = impact + stone_tick + cavern_echo
		map_two_drip_playback.push_frame(Vector2(sample, sample))

func play_footstep_tone() -> void:
	if footstep_playback == null:
		return
	var frames: int = mini(3000, footstep_playback.get_frames_available())
	for frame_index in range(frames):
		var time: float = float(frame_index) / 22050.0
		# A heavy heel impact, a hard stone click, then a very short dungeon echo.
		var thump: float = sin(TAU * 58.0 * time) * exp(-time * 34.0) * 0.42
		var stone_click: float = sin(TAU * 315.0 * time) * exp(-time * 62.0) * 0.17
		var echo_time: float = maxf(0.0, time - 0.038)
		var echo: float = sin(TAU * 71.0 * echo_time) * exp(-echo_time * 28.0) * 0.14
		var sample: float = thump + stone_click + echo
		footstep_playback.push_frame(Vector2(sample, sample))

func play_sword_swing_tone() -> void:
	if sword_playback == null:
		return
	var frames: int = mini(2700, sword_playback.get_frames_available())
	for frame_index in range(frames):
		var progress: float = float(frame_index) / float(frames)
		var envelope: float = sin(PI * progress)
		var time: float = float(frame_index) / 22050.0
		var sweep: float = sin(TAU * (150.0 * time + 940.0 * time * time))
		var air: float = sin(TAU * 1670.0 * time) * 0.28
		var sample: float = (sweep * 0.12 + air * 0.055) * envelope
		sword_playback.push_frame(Vector2(sample, sample))

func build_dungeon() -> void:
	var is_map_two: bool = map_index == 1
	var floor: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(active_map[0].length() * CELL, active_map.size() * CELL)
	floor.mesh = plane
	floor.material_override = material(Color("29261f") if is_map_two else Color("3b362c"), 0.96 if is_map_two else 0.94)
	floor.position = Vector3((active_map[0].length()-1)*CELL/2.0, 0, (active_map.size()-1)*CELL/2.0)
	world_root.add_child(floor)
	var ground: StaticBody3D = StaticBody3D.new()
	ground.position = floor.position + Vector3(0, -0.12, 0)
	var ground_collision: CollisionShape3D = CollisionShape3D.new()
	var ground_shape: BoxShape3D = BoxShape3D.new()
	ground_shape.size = Vector3(plane.size.x, 0.24, plane.size.y)
	ground_collision.shape = ground_shape
	ground.add_child(ground_collision)
	world_root.add_child(ground)

	var ceiling: MeshInstance3D = MeshInstance3D.new()
	var ceiling_mesh: PlaneMesh = PlaneMesh.new()
	ceiling_mesh.size = plane.size
	ceiling.mesh = ceiling_mesh
	ceiling.material_override = material(Color("141713") if is_map_two else Color("20221f"), 1.0 if is_map_two else 0.97)
	ceiling.position = floor.position + Vector3(0, WALL_HEIGHT, 0)
	world_root.add_child(ceiling)

	for z in active_map.size():
		for x in active_map[z].length():
			var tile: String = active_map[z][x]
			var pos: Vector3 = Vector3(x * CELL, WALL_HEIGHT/2.0, z * CELL)
			if tile == "#": create_wall(pos)
	if map_index == 0:
		create_enemy(Vector3(8.0 * CELL, 0.7, 3.0 * CELL))
		create_enemy(Vector3(3.0 * CELL, 0.7, 5.0 * CELL))
		create_portal(Vector3(10.0 * CELL, 0.0, 7.0 * CELL))
		create_health_pickup(Vector3(2.0 * CELL, 0.0, 3.0 * CELL))
		# Two identical mystery chests. Sword and glove positions are shuffled each run.
		if weapon_choice == "":
			var first_item: String = "sword" if ambience_rng.randi() % 2 == 0 else "glove"
			var second_item: String = "glove" if first_item == "sword" else "sword"
			create_choice_chest(Vector3(4.0 * CELL, 0.0, 1.0 * CELL), first_item)
			create_choice_chest(Vector3(6.0 * CELL, 0.0, 1.0 * CELL), second_item)
		create_trap(Vector3(9.0 * CELL, 0.0, 1.0 * CELL))
		create_trap(Vector3(10.0 * CELL, 0.0, 5.0 * CELL))
		create_wall_trap(Vector3(5.0 * CELL, 1.25, 3.0 * CELL), Vector3.LEFT)
		create_wall_trap(Vector3(6.0 * CELL, 1.25, 6.0 * CELL), Vector3.BACK)
	else:
		create_enemy(Vector3(8.0 * CELL, 0.7, 3.0 * CELL))
		create_enemy(Vector3(10.0 * CELL, 0.7, 7.0 * CELL))
		create_clown_enemy(Vector3(14.0 * CELL, 0.7, 9.0 * CELL))
		create_health_pickup(Vector3(6.0 * CELL, 0.0, 7.0 * CELL))
		create_trap(Vector3(4.0 * CELL, 0.0, 3.0 * CELL))
		create_trap(Vector3(12.0 * CELL, 0.0, 7.0 * CELL))
		create_wall_trap(Vector3(11.0 * CELL, 1.25, 3.0 * CELL), Vector3.LEFT)
		create_wall_trap(Vector3(12.0 * CELL, 1.25, 8.0 * CELL), Vector3.BACK)
	# [wall tile centre, room-facing normal, energy, range]. Faces alternate across
	# each corridor; no fixture is placed in the centre path or at an enemy spawn.
	var torch_layout: Array = []
	if map_index == 0:
		torch_layout = [
			[Vector3(2 * CELL, 2.05, 0), Vector3.BACK, 1.55, 5.2],
			[Vector3(8 * CELL, 2.05, 0), Vector3.BACK, 1.40, 4.9],
			[Vector3(2 * CELL, 2.05, 2 * CELL), Vector3.FORWARD, 1.25, 4.6],
			[Vector3(5 * CELL, 2.05, 2 * CELL), Vector3.FORWARD, 1.22, 4.5],
			[Vector3(5 * CELL, 2.05, 3 * CELL), Vector3.LEFT, 1.42, 5.0],
			[Vector3(5 * CELL, 2.05, 5 * CELL), Vector3.LEFT, 1.28, 4.7],
			[Vector3(6 * CELL, 2.05, 6 * CELL), Vector3.BACK, 1.32, 4.8],
			[Vector3(10 * CELL, 2.05, 8 * CELL), Vector3.FORWARD, 1.24, 4.6]
		]
	else:
		torch_layout = [
			[Vector3(2 * CELL, 2.05, 0), Vector3.BACK, 1.50, 5.0],
			[Vector3(8 * CELL, 2.05, 0), Vector3.BACK, 1.40, 4.8],
			[Vector3(5 * CELL, 2.05, 1 * CELL), Vector3.LEFT, 1.25, 4.5],
			[Vector3(5 * CELL, 2.05, 2 * CELL), Vector3.RIGHT, 1.30, 4.7],
			[Vector3(11 * CELL, 2.05, 3 * CELL), Vector3.LEFT, 1.36, 4.8],
			[Vector3(5 * CELL, 2.05, 4 * CELL), Vector3.FORWARD, 1.25, 4.5],
			[Vector3(9 * CELL, 2.05, 4 * CELL), Vector3.FORWARD, 1.28, 4.7],
			[Vector3(11 * CELL, 2.05, 5 * CELL), Vector3.LEFT, 1.32, 4.8],
			[Vector3(9 * CELL, 2.05, 6 * CELL), Vector3.BACK, 1.25, 4.5],
			[Vector3(13 * CELL, 2.05, 6 * CELL), Vector3.BACK, 1.30, 4.8],
			[Vector3(12 * CELL, 2.05, 8 * CELL), Vector3.BACK, 1.34, 4.8],
			[Vector3(13 * CELL, 2.05, 10 * CELL), Vector3.FORWARD, 1.25, 4.5],
			[Vector3(14 * CELL, 2.05, 11 * CELL), Vector3.FORWARD, 1.20, 4.5]
		]
	for torch_data in torch_layout:
		create_torch(torch_data[0], torch_data[1], torch_data[2], torch_data[3])

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58, -28, 0)
	light.light_energy = 0.66 if is_map_two else 0.92
	light.shadow_enabled = true
	world_root.add_child(light)
	var ambient: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("070b0d") if is_map_two else Color("121719")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("3c5965") if is_map_two else Color("75818a")
	environment.ambient_light_energy = 0.27 if is_map_two else 0.46
	environment.fog_enabled = true
	environment.fog_light_color = Color("1c3037") if is_map_two else Color("485257")
	environment.fog_light_energy = 0.82 if is_map_two else 0.70
	environment.fog_density = 0.019 if is_map_two else 0.011
	environment.fog_sky_affect = 0.38 if is_map_two else 0.24
	environment.glow_enabled = true
	environment.glow_intensity = 0.62 if is_map_two else 0.52
	ambient.environment = environment
	world_root.add_child(ambient)

func create_wall(pos: Vector3) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = pos
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(CELL, WALL_HEIGHT, CELL)
	mesh_instance.mesh = box
	mesh_instance.material_override = wall_material
	wall.add_child(mesh_instance)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = box.size
	collider.shape = shape
	wall.add_child(collider)
	world_root.add_child(wall)

func create_torch(wall_center: Vector3, outward: Vector3, energy: float, light_range: float) -> void:
	var fixture: Node3D = Node3D.new()
	# `outward` points from the wall into the playable room. With use_model_front=true,
	# fixture local +Z faces the room (the visible/front side of Sprite3D).
	fixture.position = wall_center + outward * (CELL * 0.5 - 0.035)
	fixture.look_at(fixture.position + outward, Vector3.UP, true)
	world_root.add_child(fixture)
	var torch_sprite: Sprite3D = Sprite3D.new()
	torch_sprite.texture = load("res://assets/wall_torch.png")
	torch_sprite.pixel_size = 0.0012
	# Keep it fixed to the wall rather than facing the player like an enemy billboard.
	torch_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# The torch image includes its own flame lighting. Keeping it unshaded prevents a
	# dark wall or a Compatibility-renderer light limit from making it disappear.
	torch_sprite.shaded = false
	torch_sprite.no_depth_test = false
	# Sprite3D's front is local +Z. Move it slightly into the room to avoid wall
	# depth clipping/z-fighting; do not rotate it back into the wall.
	torch_sprite.position = Vector3(0, 0.0, 0.065)
	fixture.add_child(torch_sprite)
	var flame: OmniLight3D = OmniLight3D.new()
	flame.position = Vector3(0, 0.09, 0.28)
	flame.light_color = Color("ff9b45")
	flame.light_energy = energy
	flame.omni_range = light_range
	flame.omni_attenuation = 1.45
	# Many soft lights look more natural in this small dungeon and remain inexpensive.
	flame.shadow_enabled = false
	fixture.add_child(flame)

func create_portal(pos: Vector3) -> void:
	portal_active = true
	portal_dismissed = false
	portal_position = pos
	var portal: Node3D = Node3D.new()
	portal.position = pos + Vector3(0, 1.15, 0)
	var portal_mesh: MeshInstance3D = MeshInstance3D.new()
	var portal_shape: CylinderMesh = CylinderMesh.new()
	portal_shape.top_radius = 0.72
	portal_shape.bottom_radius = 0.72
	portal_shape.height = 2.3
	portal_mesh.mesh = portal_shape
	var portal_material: StandardMaterial3D = material(Color(0.12, 0.68, 1.0, 0.58), 0.18)
	portal_material.emission_enabled = true
	portal_material.emission = Color("38c9ff")
	portal_material.emission_energy_multiplier = 2.1
	portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_mesh.material_override = portal_material
	portal.add_child(portal_mesh)
	var portal_light: OmniLight3D = OmniLight3D.new()
	portal_light.light_color = Color("42cfff")
	portal_light.light_energy = 1.65
	portal_light.omni_range = 4.4
	portal.add_child(portal_light)
	world_root.add_child(portal)

func create_health_pickup(pos: Vector3) -> void:
	health_pickup_active = true
	health_pickup_base_position = pos + Vector3(0, 0.68, 0)
	health_pickup = Node3D.new()
	health_pickup.position = health_pickup_base_position
	var heart_material: StandardMaterial3D = material(Color("ed2639"), 0.45)
	heart_material.emission_enabled = true
	heart_material.emission = Color("ff2038")
	heart_material.emission_energy_multiplier = 1.35
	# Two faceted lobes and a downward point make a 3D polygon heart silhouette.
	for side in [-1.0, 1.0]:
		var lobe: MeshInstance3D = MeshInstance3D.new()
		var lobe_mesh: SphereMesh = SphereMesh.new()
		lobe_mesh.radius = 0.30
		lobe_mesh.height = 0.60
		lobe_mesh.radial_segments = 6
		lobe_mesh.rings = 3
		lobe.mesh = lobe_mesh
		lobe.material_override = heart_material
		lobe.position = Vector3(side * 0.22, 0.18, 0)
		health_pickup.add_child(lobe)
	var point: MeshInstance3D = MeshInstance3D.new()
	var point_mesh: CylinderMesh = CylinderMesh.new()
	point_mesh.top_radius = 0.39
	point_mesh.bottom_radius = 0.0
	point_mesh.height = 0.62
	point_mesh.radial_segments = 6
	point.mesh = point_mesh
	point.material_override = heart_material
	point.position = Vector3(0, -0.18, 0)
	health_pickup.add_child(point)
	world_root.add_child(health_pickup)

func update_health_pickup(delta: float) -> void:
	if not health_pickup_active or not is_instance_valid(health_pickup):
		return
	health_pickup.position = health_pickup_base_position + Vector3(0, sin(Time.get_ticks_msec() * 0.004) * 0.12, 0)
	health_pickup.rotate_y(delta * 1.8)
	var flat_to_pickup: Vector3 = player.global_position - health_pickup_base_position
	flat_to_pickup.y = 0.0
	if flat_to_pickup.length() < 0.80:
		health = minf(MAX_HEALTH, health + 16.0)
		health_pickup_active = false
		play_world_sfx("heart")
		health_pickup.queue_free()

func create_trap(pos: Vector3) -> void:
	var trap: Node3D = Node3D.new()
	trap.position = pos
	trap.set_meta("triggered", false)
	trap.set_meta("reveal", 0.0)
	# The dark low plate and two thin slashes blend with the stone floor until triggered.
	var plate: MeshInstance3D = MeshInstance3D.new()
	var plate_mesh: CylinderMesh = CylinderMesh.new()
	plate_mesh.top_radius = 0.52
	plate_mesh.bottom_radius = 0.48
	plate_mesh.height = 0.025
	plate_mesh.radial_segments = 6
	plate.mesh = plate_mesh
	plate.material_override = material(Color("15120f"), 0.98)
	plate.position = Vector3(0, 0.015, 0)
	trap.add_child(plate)
	var crack_material: StandardMaterial3D = material(Color("070706"), 1.0)
	for crack_rotation in [-18.0, 27.0]:
		var crack: MeshInstance3D = MeshInstance3D.new()
		var crack_mesh: BoxMesh = BoxMesh.new()
		crack_mesh.size = Vector3(0.78, 0.018, 0.035)
		crack.mesh = crack_mesh
		crack.material_override = crack_material
		crack.position = Vector3(0, 0.035, 0)
		crack.rotation_degrees.y = crack_rotation
		trap.add_child(crack)
	var spikes: Node3D = Node3D.new()
	spikes.name = "Spikes"
	spikes.position.y = -0.42
	var spike_material: StandardMaterial3D = material(Color("7f8382"), 0.38)
	spike_material.metallic = 0.65
	for spike_offset in [Vector3(-0.22, 0, -0.16), Vector3(0.20, 0, -0.18), Vector3(-0.12, 0, 0.20), Vector3(0.25, 0, 0.18)]:
		var spike: MeshInstance3D = MeshInstance3D.new()
		var spike_mesh: CylinderMesh = CylinderMesh.new()
		spike_mesh.top_radius = 0.0
		spike_mesh.bottom_radius = 0.11
		spike_mesh.height = 0.78
		spike_mesh.radial_segments = 6
		spike.mesh = spike_mesh
		spike.material_override = spike_material
		spike.position = spike_offset
		spikes.add_child(spike)
	trap.add_child(spikes)
	world_root.add_child(trap)
	traps.append(trap)

func update_traps(delta: float) -> void:
	var active_traps: Array[Node3D] = []
	for trap in traps:
		if not is_instance_valid(trap):
			continue
		var triggered: bool = bool(trap.get_meta("triggered", false))
		if not triggered:
			var flat_distance: Vector3 = player.global_position - trap.global_position
			flat_distance.y = 0.0
			if flat_distance.length() < 0.70:
				trap.set_meta("triggered", true)
				triggered = true
				apply_damage(10.0)
				play_world_sfx("trap")
		if triggered:
			var reveal: float = minf(1.0, float(trap.get_meta("reveal", 0.0)) + delta * 7.0)
			trap.set_meta("reveal", reveal)
			var spikes: Node3D = trap.get_node("Spikes") as Node3D
			spikes.position.y = lerpf(-0.42, 0.20, reveal)
		active_traps.append(trap)
	traps = active_traps

func create_wall_trap(wall_center: Vector3, outward: Vector3) -> void:
	var trap: Node3D = Node3D.new()
	# Put the panel pivot just inside the true box-wall surface. Local +Z is the room side.
	trap.position = wall_center + outward * (CELL * 0.5 - 0.012)
	trap.rotation.y = atan2(outward.x, outward.z)
	trap.set_meta("normal", outward)
	trap.set_meta("triggered", false)
	trap.set_meta("reveal", 0.0)
	var plate: MeshInstance3D = MeshInstance3D.new()
	var plate_mesh: BoxMesh = BoxMesh.new()
	plate_mesh.size = Vector3(0.92, 0.90, 0.055)
	plate.mesh = plate_mesh
	plate.material_override = material(Color("15120f"), 0.98)
	plate.position = Vector3.ZERO
	trap.add_child(plate)
	var crack_material: StandardMaterial3D = material(Color("050504"), 1.0)
	for crack_angle in [-16.0, 22.0]:
		var crack: MeshInstance3D = MeshInstance3D.new()
		var crack_mesh: BoxMesh = BoxMesh.new()
		crack_mesh.size = Vector3(0.74, 0.035, 0.018)
		crack.mesh = crack_mesh
		crack.material_override = crack_material
		crack.position = Vector3(0, 0, 0.034)
		crack.rotation_degrees.z = crack_angle
		trap.add_child(crack)
	var spikes: Node3D = Node3D.new()
	spikes.name = "WallSpikes"
	spikes.position.z = -0.48
	var spike_material: StandardMaterial3D = material(Color("9b9e9a"), 0.32)
	spike_material.metallic = 0.70
	for spike_offset in [Vector3(-0.24, 0.22, 0), Vector3(0.24, 0.22, 0), Vector3(0, -0.20, 0)]:
		var spike: MeshInstance3D = MeshInstance3D.new()
		var spike_mesh: CylinderMesh = CylinderMesh.new()
		spike_mesh.top_radius = 0.0
		spike_mesh.bottom_radius = 0.12
		spike_mesh.height = 0.78
		spike_mesh.radial_segments = 6
		spike.mesh = spike_mesh
		spike.material_override = spike_material
		spike.position = spike_offset
		spike.rotation_degrees.x = 90.0
		spikes.add_child(spike)
	trap.add_child(spikes)
	world_root.add_child(trap)
	wall_traps.append(trap)

func update_wall_traps(delta: float) -> void:
	var active_wall_traps: Array[Node3D] = []
	for trap in wall_traps:
		if not is_instance_valid(trap):
			continue
		var triggered: bool = bool(trap.get_meta("triggered", false))
		if not triggered:
			var to_player: Vector3 = player.global_position - trap.global_position
			to_player.y = 0.0
			var outward: Vector3 = trap.get_meta("normal", Vector3.ZERO)
			if to_player.length() < 1.90 and to_player.normalized().dot(outward) > 0.55:
				trap.set_meta("triggered", true)
				triggered = true
				apply_damage(10.0)
		if triggered:
			var reveal: float = minf(1.0, float(trap.get_meta("reveal", 0.0)) + delta * 9.0)
			trap.set_meta("reveal", reveal)
			var spikes: Node3D = trap.get_node("WallSpikes") as Node3D
			spikes.position.z = lerpf(-0.48, 0.38, reveal)
		active_wall_traps.append(trap)
	wall_traps = active_wall_traps

func create_sword_chest(pos: Vector3, opened: bool = false) -> void:
	sword_chest_active = not opened
	sword_chest_position = pos
	sword_chest = Node3D.new()
	sword_chest.position = pos
	var wood: StandardMaterial3D = material(Color("5a301a"), 0.82)
	var metal: StandardMaterial3D = material(Color("b98a35"), 0.34)
	metal.metallic = 0.68
	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: BoxMesh = BoxMesh.new()
	base_mesh.size = Vector3(1.16, 0.52, 0.76)
	base.mesh = base_mesh
	base.material_override = wood
	base.position = Vector3(0, 0.26, 0)
	sword_chest.add_child(base)
	sword_chest_lid = MeshInstance3D.new()
	var lid_mesh: BoxMesh = BoxMesh.new()
	lid_mesh.size = Vector3(1.20, 0.24, 0.82)
	sword_chest_lid.mesh = lid_mesh
	sword_chest_lid.material_override = wood
	sword_chest_lid.position = Vector3(0, 0.63, 0)
	sword_chest.add_child(sword_chest_lid)
	for side in [-1.0, 1.0]:
		var band: MeshInstance3D = MeshInstance3D.new()
		var band_mesh: BoxMesh = BoxMesh.new()
		band_mesh.size = Vector3(0.075, 0.70, 0.84)
		band.mesh = band_mesh
		band.material_override = metal
		band.position = Vector3(side * 0.38, 0.37, 0)
		sword_chest.add_child(band)
	sword_chest_lock = MeshInstance3D.new()
	var lock_mesh: BoxMesh = BoxMesh.new()
	lock_mesh.size = Vector3(0.20, 0.25, 0.08)
	sword_chest_lock.mesh = lock_mesh
	var lock_material: StandardMaterial3D = material(Color("f0bc46"), 0.25)
	lock_material.metallic = 0.72
	lock_material.emission_enabled = true
	lock_material.emission = Color("d98a22")
	lock_material.emission_energy_multiplier = 0.55
	sword_chest_lock.material_override = lock_material
	sword_chest_lock.position = Vector3(0, 0.44, -0.42)
	sword_chest.add_child(sword_chest_lock)
	var chest_light: OmniLight3D = OmniLight3D.new()
	chest_light.light_color = Color("ffbd4a")
	chest_light.light_energy = 0.42
	chest_light.omni_range = 2.0
	chest_light.shadow_enabled = false
	chest_light.position = Vector3(0, 0.72, 0)
	sword_chest.add_child(chest_light)
	if opened:
		sword_chest_lid.position = Vector3(0, 0.84, 0.27)
		sword_chest_lid.rotation_degrees.x = -108.0
		sword_chest_lock.visible = false
	world_root.add_child(sword_chest)

func can_draw_sword() -> bool:
	if sword_owned or not sword_chest_active or not is_instance_valid(sword_chest):
		return false
	var flat_distance: Vector3 = player.global_position - sword_chest_position
	flat_distance.y = 0.0
	return flat_distance.length() < 1.55

func equip_sword() -> void:
	if not can_draw_sword():
		return
	sword_owned = true
	sword_chest_active = false
	sword.visible = true
	weapon_prompt.visible = false
	play_world_sfx("equip")
	# Keep the opened chest in the world as feedback rather than deleting it.
	sword_chest_lid.position = Vector3(0, 0.84, 0.27)
	sword_chest_lid.rotation_degrees.x = -108.0
	sword_chest_lock.visible = false

func update_sword_chest() -> void:
	if sword_owned or not sword_chest_active:
		weapon_prompt.visible = false
		return
	weapon_prompt.visible = can_draw_sword()

func create_choice_chest(pos: Vector3, item: String) -> void:
	var chest: Node3D = Node3D.new()
	chest.position = pos
	chest.set_meta("item", item)
	var wood: StandardMaterial3D = material(Color("5a301a"), 0.82)
	var metal: StandardMaterial3D = material(Color("b98a35"), 0.34)
	metal.metallic = 0.68
	var base: MeshInstance3D = MeshInstance3D.new()
	var base_mesh: BoxMesh = BoxMesh.new()
	base_mesh.size = Vector3(1.16, 0.52, 0.76)
	base.mesh = base_mesh
	base.material_override = wood
	base.position = Vector3(0, 0.26, 0)
	chest.add_child(base)
	var lid: MeshInstance3D = MeshInstance3D.new()
	lid.name = "Lid"
	var lid_mesh: BoxMesh = BoxMesh.new()
	lid_mesh.size = Vector3(1.20, 0.24, 0.82)
	lid.mesh = lid_mesh
	lid.material_override = wood
	lid.position = Vector3(0, 0.63, 0)
	chest.add_child(lid)
	for side in [-1.0, 1.0]:
		var band: MeshInstance3D = MeshInstance3D.new()
		var band_mesh: BoxMesh = BoxMesh.new()
		band_mesh.size = Vector3(0.075, 0.70, 0.84)
		band.mesh = band_mesh
		band.material_override = metal
		band.position = Vector3(side * 0.38, 0.37, 0)
		chest.add_child(band)
	var lock: MeshInstance3D = MeshInstance3D.new()
	lock.name = "Lock"
	var lock_mesh: BoxMesh = BoxMesh.new()
	lock_mesh.size = Vector3(0.20, 0.25, 0.08)
	lock.mesh = lock_mesh
	lock.material_override = metal
	lock.position = Vector3(0, 0.44, -0.42)
	chest.add_child(lock)
	var chest_light: OmniLight3D = OmniLight3D.new()
	chest_light.light_color = Color("ffbd4a")
	chest_light.light_energy = 0.40
	chest_light.omni_range = 2.0
	chest_light.position = Vector3(0, 0.72, 0)
	chest.add_child(chest_light)
	world_root.add_child(chest)
	choice_chests.append(chest)

func nearby_choice_chest() -> Node3D:
	if weapon_choice != "":
		return null
	for chest in choice_chests:
		if not is_instance_valid(chest):
			continue
		var offset: Vector3 = player.global_position - chest.global_position
		offset.y = 0.0
		if offset.length() < 1.55:
			return chest
	return null

func choose_nearby_weapon() -> void:
	var selected: Node3D = nearby_choice_chest()
	if selected == null:
		return
	weapon_choice = String(selected.get_meta("item", "sword"))
	sword_owned = weapon_choice == "sword"
	sword.visible = sword_owned
	magic_glove.visible = weapon_choice == "glove"
	magic_reticle.visible = weapon_choice == "glove"
	weapon_prompt.visible = false
	play_world_sfx("equip")
	for chest in choice_chests:
		if not is_instance_valid(chest):
			continue
		if chest == selected:
			var lid: MeshInstance3D = chest.get_node("Lid") as MeshInstance3D
			var lock: MeshInstance3D = chest.get_node("Lock") as MeshInstance3D
			lid.position = Vector3(0, 0.84, 0.27)
			lid.rotation_degrees.x = -108.0
			lock.visible = false
		else:
			chest.queue_free()
	choice_chests = [selected]

func update_choice_chests() -> void:
	if weapon_choice != "" or map_index != 0:
		weapon_prompt.visible = false
		return
	weapon_prompt.text = "E: 상자 하나 선택"
	weapon_prompt.visible = nearby_choice_chest() != null

func create_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(2.0 * CELL, 1.05, 1.0 * CELL)
	player.collision_layer = 2
	player.collision_mask = 1
	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	collider.shape = capsule
	player.add_child(collider)
	add_child(player)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.52, 0)
	camera.current = true
	player.add_child(camera)
	create_sword()
	create_magic_glove()

func create_sword() -> void:
	sword = Node3D.new()
	sword.position = Vector3(0.42, -0.36, -1.25)
	sword.visible = sword_owned
	camera.add_child(sword)
	var sword_sprite: Sprite3D = Sprite3D.new()
	sword_sprite.texture = load("res://assets/viking_sword.png")
	sword_sprite.pixel_size = 0.00082
	# It is a view-model asset: always crisp in front of the dungeon, not billboarded.
	sword_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sword_sprite.shaded = false
	sword_sprite.no_depth_test = true
	sword.add_child(sword_sprite)

func create_magic_glove() -> void:
	magic_glove = Node3D.new()
	magic_glove.position = Vector3(0.48, -0.38, -1.05)
	magic_glove.visible = weapon_choice == "glove"
	camera.add_child(magic_glove)
	var palm: MeshInstance3D = MeshInstance3D.new()
	var palm_mesh: BoxMesh = BoxMesh.new()
	palm_mesh.size = Vector3(0.30, 0.38, 0.24)
	palm.mesh = palm_mesh
	var glove_material: StandardMaterial3D = material(Color("1759a6"), 0.38)
	glove_material.emission_enabled = true
	glove_material.emission = Color("238dff")
	glove_material.emission_energy_multiplier = 0.45
	palm.material_override = glove_material
	magic_glove.add_child(palm)
	for finger_index in 3:
		var finger: MeshInstance3D = MeshInstance3D.new()
		var finger_mesh: CapsuleMesh = CapsuleMesh.new()
		finger_mesh.radius = 0.045
		finger_mesh.height = 0.24
		finger.mesh = finger_mesh
		finger.material_override = glove_material
		finger.position = Vector3((finger_index - 1) * 0.09, 0.21, -0.04)
		magic_glove.add_child(finger)
	var core: MeshInstance3D = MeshInstance3D.new()
	var core_mesh: SphereMesh = SphereMesh.new()
	core_mesh.radius = 0.075
	core_mesh.height = 0.15
	core.mesh = core_mesh
	var core_material: StandardMaterial3D = material(Color("bcefff"), 0.20)
	core_material.emission_enabled = true
	core_material.emission = Color("39b8ff")
	core_material.emission_energy_multiplier = 2.0
	core.material_override = core_material
	core.position = Vector3(0, 0.02, -0.14)
	magic_glove.add_child(core)

func create_enemy(pos: Vector3) -> void:
	var enemy: CharacterBody3D = CharacterBody3D.new()
	# Ghosts hover above the floor; their collider rises with the same body transform.
	enemy.position = Vector3(pos.x, 0.24, pos.z)
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	enemy.set_meta("is_3d_enemy", true)
	enemy.set_meta("is_ghost", true)
	enemy.set_meta("hover_phase", pos.x * 0.31 + pos.z * 0.17)
	var model: Node3D = Node3D.new()
	# A flared, faceted sheet gives the ghost its hovering cloth silhouette.
	add_ghost_cloth(model, Vector3(0, 0.67, 0), Vector3(1.0, 1.0, 1.0), Color("e6e6d7"))
	add_ghost_sphere(model, Vector3(0, 1.30, -0.03), Vector3(0.68, 0.72, 0.64), Color("f4f2e6"))
	# Uneven low-poly folds along the lower edge keep it from reading as a plain cone.
	add_ghost_sphere(model, Vector3(-0.40, 0.32, -0.08), Vector3(0.42, 0.34, 0.36), Color("dddccd"))
	add_ghost_sphere(model, Vector3(0.00, 0.26, -0.17), Vector3(0.46, 0.30, 0.38), Color("e8e4d8"))
	add_ghost_sphere(model, Vector3(0.40, 0.32, -0.08), Vector3(0.42, 0.34, 0.36), Color("dddccd"))
	# Facial features sit on the front (-Z) surface of the head.
	add_ghost_sphere(model, Vector3(-0.15, 1.38, -0.34), Vector3(0.14, 0.20, 0.07), Color("121216"))
	add_ghost_sphere(model, Vector3(0.15, 1.38, -0.34), Vector3(0.14, 0.20, 0.07), Color("121216"))
	add_ghost_sphere(model, Vector3(0.00, 1.15, -0.38), Vector3(0.16, 0.22, 0.07), Color("121216"))
	enemy.add_child(model)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.42
	shape.height = 1.45
	collider.shape = shape
	collider.position = Vector3(0, 0.72, 0)
	enemy.add_child(collider)
	world_root.add_child(enemy)
	enemies.append(enemy)

func create_clown_enemy(pos: Vector3) -> void:
	var enemy: CharacterBody3D = CharacterBody3D.new()
	# The boss is placed at a deep open tile with at least one full cell of wall clearance.
	enemy.position = Vector3(pos.x, 0.03, pos.z)
	enemy.collision_layer = 4
	enemy.collision_mask = 1
	enemy.set_meta("is_3d_enemy", true)
	enemy.set_meta("is_clown", true)
	enemy.set_meta("is_boss", true)
	enemy.set_meta("boss_health", BOSS_HEALTH)
	enemy.set_meta("ranged_cooldown", 1.4)
	enemy.set_meta("vulnerable_time", 0.0)
	var model: Node3D = Node3D.new()
	model.name = "BossModel"
	model.scale = Vector3(1.35, 1.35, 1.35)
	# Low-poly body and bright, mismatched costume.
	add_clown_cylinder(model, Vector3(0, 0.93, 0), Vector3(0.72, 0.92, 0.58), Color("386fd8"))
	add_clown_sphere(model, Vector3(0, 1.72, -0.03), Vector3(0.88, 0.88, 0.80), Color("f3e8d2"))
	# Large curly red hair: three faceted clumps on each side of the white face.
	for hair_side in [-1.0, 1.0]:
		add_clown_sphere(model, Vector3(hair_side * 0.48, 1.86, 0.02), Vector3(0.48, 0.54, 0.42), Color("d62c2c"))
		add_clown_sphere(model, Vector3(hair_side * 0.55, 1.58, 0.03), Vector3(0.40, 0.42, 0.38), Color("e23a2f"))
		add_clown_sphere(model, Vector3(hair_side * 0.32, 2.12, 0.01), Vector3(0.36, 0.38, 0.35), Color("bf2026"))
	# Facial parts sit slightly in front of the head (-Z) so they remain visible.
	add_clown_sphere(model, Vector3(-0.17, 1.83, -0.40), Vector3(0.12, 0.16, 0.08), Color("17151a"))
	add_clown_sphere(model, Vector3(0.17, 1.83, -0.40), Vector3(0.12, 0.16, 0.08), Color("17151a"))
	add_clown_sphere(model, Vector3(0, 1.67, -0.48), Vector3(0.17, 0.17, 0.12), Color("ef2525"))
	add_clown_sphere(model, Vector3(0, 1.49, -0.43), Vector3(0.34, 0.13, 0.07), Color("2a1016"))
	# Striped sleeves, coloured buttons, and boxy shoes make the silhouette distinct.
	add_clown_cylinder(model, Vector3(-0.52, 0.98, 0), Vector3(0.24, 0.58, 0.24), Color("f1b62e"), 52.0)
	add_clown_cylinder(model, Vector3(0.52, 0.98, 0), Vector3(0.24, 0.58, 0.24), Color("d83a91"), -52.0)
	add_clown_sphere(model, Vector3(0, 1.13, -0.36), Vector3(0.10, 0.10, 0.07), Color("f1c432"))
	add_clown_sphere(model, Vector3(0, 0.88, -0.38), Vector3(0.10, 0.10, 0.07), Color("dc3b3b"))
	add_clown_box(model, Vector3(-0.22, 0.27, -0.04), Vector3(0.42, 0.20, 0.58), Color("4a2c83"))
	add_clown_box(model, Vector3(0.22, 0.27, -0.04), Vector3(0.42, 0.20, 0.58), Color("4a2c83"))
	enemy.add_child(model)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.65
	shape.height = 2.15
	collider.shape = shape
	collider.position = Vector3(0, 1.07, 0)
	enemy.add_child(collider)
	world_root.add_child(enemy)
	enemies.append(enemy)

func add_clown_sphere(parent: Node3D, pos: Vector3, part_scale: Vector3, color: Color) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	part.mesh = mesh
	part.material_override = material(color, 0.74)
	part.position = pos
	part.scale = part_scale
	parent.add_child(part)

func add_ghost_sphere(parent: Node3D, pos: Vector3, part_scale: Vector3, color: Color) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 4
	part.mesh = mesh
	part.material_override = material(color, 0.90)
	part.position = pos
	part.scale = part_scale
	parent.add_child(part)

func add_ghost_cloth(parent: Node3D, pos: Vector3, part_scale: Vector3, color: Color) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.72
	mesh.height = 1.25
	mesh.radial_segments = 8
	part.mesh = mesh
	part.material_override = material(color, 0.92)
	part.position = pos
	part.scale = part_scale
	parent.add_child(part)

func add_clown_cylinder(parent: Node3D, pos: Vector3, part_scale: Vector3, color: Color, z_rotation: float = 0.0) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 8
	part.mesh = mesh
	part.material_override = material(color, 0.72)
	part.position = pos
	part.scale = part_scale
	part.rotation_degrees.z = z_rotation
	parent.add_child(part)

func add_clown_box(parent: Node3D, pos: Vector3, part_scale: Vector3, color: Color) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	part.mesh = mesh
	part.material_override = material(color, 0.80)
	part.position = pos
	part.scale = part_scale
	parent.add_child(part)

func update_boss_vulnerability_visual(boss: CharacterBody3D, active: bool) -> void:
	var model: Node3D = boss.get_node_or_null("BossModel") as Node3D
	if model == null:
		return
	if active:
		model.position.y = sin(Time.get_ticks_msec() * 0.012) * 0.10
		model.rotation_degrees.z = sin(Time.get_ticks_msec() * 0.018) * 5.0
	else:
		model.position = Vector3.ZERO
		model.rotation_degrees.z = 0.0

func clown_has_clear_shot(owner: CharacterBody3D, target: Vector3) -> bool:
	var ray_start: Vector3 = owner.global_position + Vector3(0, 1.15, 0)
	# Layer 1 is world walls/ground and layer 2 is the player. A player first-hit is valid;
	# any world hit before it means the shot is blocked.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_start, target, 3)
	query.exclude = [owner.get_rid()]
	var first_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if first_hit.is_empty():
		return true
	return first_hit.get("collider") == player

func create_clown_projectile(owner: CharacterBody3D, direction: Vector3) -> void:
	var launch_origin: Vector3 = owner.global_position + Vector3(0, 1.15, 0)
	var shot_direction: Vector3 = direction.normalized()
	var projectile: CharacterBody3D = CharacterBody3D.new()
	projectile.position = launch_origin + shot_direction * 1.16
	projectile.collision_layer = 8
	projectile.collision_mask = 3
	var ball: MeshInstance3D = MeshInstance3D.new()
	var ball_mesh: SphereMesh = SphereMesh.new()
	ball_mesh.radius = 0.30
	ball_mesh.height = 0.60
	ball_mesh.radial_segments = 6
	ball_mesh.rings = 3
	ball.mesh = ball_mesh
	var ball_color: Color = Color("ff2028")
	var ball_material: StandardMaterial3D = material(ball_color, 0.34)
	ball_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ball_material.emission_enabled = true
	ball_material.emission = ball_color
	ball_material.emission_energy_multiplier = 2.3
	ball.material_override = ball_material
	projectile.add_child(ball)
	var trail: MeshInstance3D = MeshInstance3D.new()
	var trail_mesh: SphereMesh = SphereMesh.new()
	trail_mesh.radius = 0.5
	trail_mesh.height = 1.0
	trail_mesh.radial_segments = 6
	trail_mesh.rings = 3
	trail.mesh = trail_mesh
	var trail_material: StandardMaterial3D = material(Color(ball_color, 0.48), 0.50)
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.emission_enabled = true
	trail_material.emission = ball_color
	trail_material.emission_energy_multiplier = 1.45
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail.material_override = trail_material
	trail.position = -shot_direction * 0.42
	trail.scale = Vector3(0.19, 0.19, 0.72)
	projectile.add_child(trail)
	trail.look_at(trail.global_position - shot_direction, Vector3.UP)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.30
	collider.shape = shape
	projectile.add_child(collider)
	projectile.set_meta("velocity", shot_direction * 7.5)
	projectile.set_meta("lifetime", 3.0)
	world_root.add_child(projectile)
	clown_projectiles.append(projectile)

func create_clown_volley(owner: CharacterBody3D, target: Vector3) -> int:
	var launch_origin: Vector3 = owner.global_position + Vector3(0, 1.15, 0)
	var base_direction: Vector3 = (target - launch_origin).normalized()
	var shots_fired: int = 0
	for spread_degrees in [-12.0, 0.0, 12.0]:
		var shot_direction: Vector3 = base_direction.rotated(Vector3.UP, deg_to_rad(spread_degrees))
		var sight_target: Vector3 = launch_origin + shot_direction * 14.0
		if clown_has_clear_shot(owner, sight_target):
			create_clown_projectile(owner, shot_direction)
			shots_fired += 1
	if shots_fired > 0:
		play_enemy_sfx("volley")
	return shots_fired

func update_clown_projectiles(delta: float) -> void:
	var remaining: Array[CharacterBody3D] = []
	for projectile in clown_projectiles:
		if not is_instance_valid(projectile):
			continue
		var lifetime: float = float(projectile.get_meta("lifetime", 0.0)) - delta
		if lifetime <= 0.0:
			projectile.queue_free()
			continue
		var velocity: Vector3 = projectile.get_meta("velocity", Vector3.ZERO)
		var hit = projectile.move_and_collide(velocity * delta)
		if hit:
			if hit.get_collider() == player:
				apply_damage(8.0)
			play_enemy_sfx("impact")
			projectile.queue_free()
			continue
		projectile.set_meta("lifetime", lifetime)
		projectile.rotate_z(delta * 9.0)
		remaining.append(projectile)
	clown_projectiles = remaining

func fire_magic_ball() -> void:
	if weapon_choice != "glove" or magic_cooldown > 0.0:
		return
	magic_cooldown = 0.38
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	var ball: CharacterBody3D = CharacterBody3D.new()
	ball.global_position = camera.global_position + direction * 0.9 + Vector3(0.18, -0.12, 0)
	ball.collision_layer = 8
	ball.collision_mask = 1 | 4
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	mesh_instance.mesh = sphere
	var energy_material: StandardMaterial3D = material(Color("42bfff"), 0.16)
	energy_material.emission_enabled = true
	energy_material.emission = Color("219eff")
	energy_material.emission_energy_multiplier = 3.2
	mesh_instance.material_override = energy_material
	ball.add_child(mesh_instance)
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color("45c6ff")
	light.light_energy = 1.8
	light.omni_range = 2.2
	light.shadow_enabled = false
	ball.add_child(light)
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 0.18
	collider.shape = shape
	ball.add_child(collider)
	ball.set_meta("velocity", direction * 13.0)
	ball.set_meta("lifetime", 2.4)
	world_root.add_child(ball)
	magic_balls.append(ball)
	play_world_sfx("portal")

func update_magic_balls(delta: float) -> void:
	magic_cooldown = maxf(0.0, magic_cooldown - delta)
	var remaining: Array[CharacterBody3D] = []
	for ball in magic_balls:
		if not is_instance_valid(ball):
			continue
		var lifetime: float = float(ball.get_meta("lifetime", 0.0)) - delta
		if lifetime <= 0.0:
			ball.queue_free()
			continue
		var ball_velocity: Vector3 = ball.get_meta("velocity", Vector3.ZERO)
		var collision: KinematicCollision3D = ball.move_and_collide(ball_velocity * delta)
		if collision != null:
			var collider_object: Object = collision.get_collider()
			if collider_object is Node3D and (collider_object as Node3D).get_meta("is_3d_enemy", false):
				apply_magic_damage(collider_object as Node3D)
			ball.queue_free()
			continue
		ball.set_meta("lifetime", lifetime)
		ball.rotate_y(delta * 10.0)
		remaining.append(ball)
	magic_balls = remaining

func apply_magic_damage(enemy: Node3D) -> void:
	if enemy.get_meta("is_boss", false):
		var boss_health: float = float(enemy.get_meta("boss_health", 0.0)) - SWORD_DAMAGE
		if boss_health <= 0.0:
			enemy.queue_free()
			end_victory()
		else:
			enemy.set_meta("boss_health", boss_health)
	else:
		enemy.queue_free()
	play_enemy_sfx("impact")

func apply_damage(amount: float) -> void:
	if health <= 0.0 or damage_cooldown > 0.0:
		return
	health = maxf(0.0, health - amount)
	damage_cooldown = 0.65
	play_damage_tone()
	damage_flash = 0.9

func material(color: Color, roughness: float) -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

func dungeon_wall_material() -> StandardMaterial3D:
	var result: StandardMaterial3D = StandardMaterial3D.new()
	var stone_texture: Texture2D = load("res://assets/wall_stone.png")
	result.albedo_texture = stone_texture
	result.roughness = 0.94
	result.uv1_scale = Vector3(1.35, 1.35, 1.35)
	return result

func create_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	hurt_overlay = ColorRect.new()
	hurt_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_overlay.color = Color(0.75, 0.03, 0.02, 0.0)
	hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hurt_overlay)
	status = Label.new()
	status.position = Vector2(24, 20)
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color("f7e6bd"))
	status.add_theme_color_override("font_outline_color", Color("0b0c0d"))
	status.add_theme_constant_override("outline_size", 6)
	layer.add_child(status)
	weapon_prompt = Label.new()
	weapon_prompt.text = "E: 검 꺼내기"
	weapon_prompt.set_anchors_preset(Control.PRESET_CENTER)
	weapon_prompt.offset_left = -150.0
	weapon_prompt.offset_top = 82.0
	weapon_prompt.offset_right = 150.0
	weapon_prompt.offset_bottom = 120.0
	weapon_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_prompt.add_theme_font_size_override("font_size", 24)
	weapon_prompt.add_theme_color_override("font_color", Color("ffd36a"))
	weapon_prompt.add_theme_color_override("font_outline_color", Color("17110a"))
	weapon_prompt.add_theme_constant_override("outline_size", 6)
	weapon_prompt.visible = false
	layer.add_child(weapon_prompt)
	magic_reticle = Label.new()
	magic_reticle.text = "⊕"
	magic_reticle.set_anchors_preset(Control.PRESET_CENTER)
	magic_reticle.offset_left = -24.0
	magic_reticle.offset_top = -34.0
	magic_reticle.offset_right = 24.0
	magic_reticle.offset_bottom = 34.0
	magic_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	magic_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	magic_reticle.add_theme_font_size_override("font_size", 42)
	magic_reticle.add_theme_color_override("font_color", Color("4bc5ff"))
	magic_reticle.add_theme_color_override("font_outline_color", Color("0b2852"))
	magic_reticle.add_theme_constant_override("outline_size", 5)
	magic_reticle.visible = weapon_choice == "glove"
	layer.add_child(magic_reticle)
	var heart_empty: Label = Label.new()
	heart_empty.text = "♥ ♥ ♥ ♥ ♥"
	heart_empty.position = Vector2(24, 52)
	heart_empty.size = Vector2(170, 34)
	heart_empty.add_theme_font_size_override("font_size", 27)
	heart_empty.add_theme_color_override("font_color", Color("482126"))
	heart_empty.add_theme_color_override("font_outline_color", Color("0b0c0d"))
	heart_empty.add_theme_constant_override("outline_size", 4)
	layer.add_child(heart_empty)
	heart_fill = Label.new()
	heart_fill.text = "♥ ♥ ♥ ♥ ♥"
	heart_fill.position = heart_empty.position
	heart_fill.size = Vector2(170, 34)
	heart_fill.clip_text = true
	heart_fill.add_theme_font_size_override("font_size", 27)
	heart_fill.add_theme_color_override("font_color", Color("ed3e42"))
	heart_fill.add_theme_color_override("font_outline_color", Color("6c1118"))
	heart_fill.add_theme_constant_override("outline_size", 3)
	layer.add_child(heart_fill)
	outcome_label = Label.new()
	outcome_label.set_anchors_preset(Control.PRESET_CENTER)
	outcome_label.offset_left = -260.0
	outcome_label.offset_top = -150.0
	outcome_label.offset_right = 260.0
	outcome_label.offset_bottom = -82.0
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_label.add_theme_font_size_override("font_size", 44)
	outcome_label.add_theme_color_override("font_color", Color("f7e6bd"))
	outcome_label.add_theme_color_override("font_outline_color", Color("08090a"))
	outcome_label.add_theme_constant_override("outline_size", 8)
	outcome_label.visible = false
	layer.add_child(outcome_label)
	restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.set_anchors_preset(Control.PRESET_CENTER)
	restart_button.offset_left = -132.0
	restart_button.offset_top = -34.0
	restart_button.offset_right = 132.0
	restart_button.offset_bottom = 34.0
	restart_button.add_theme_font_size_override("font_size", 28)
	restart_button.visible = false
	restart_button.pressed.connect(restart_scene)
	layer.add_child(restart_button)
	portal_prompt = PanelContainer.new()
	portal_prompt.set_anchors_preset(Control.PRESET_CENTER)
	portal_prompt.offset_left = -230.0
	portal_prompt.offset_top = -110.0
	portal_prompt.offset_right = 230.0
	portal_prompt.offset_bottom = 110.0
	portal_prompt.visible = false
	var portal_box: VBoxContainer = VBoxContainer.new()
	portal_box.alignment = BoxContainer.ALIGNMENT_CENTER
	var portal_text: Label = Label.new()
	portal_text.text = "다음 맵으로 들어가시겠습니까?"
	portal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portal_text.add_theme_font_size_override("font_size", 24)
	portal_box.add_child(portal_text)
	var choices: HBoxContainer = HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes_button: Button = Button.new()
	yes_button.text = "예"
	yes_button.custom_minimum_size = Vector2(120, 48)
	yes_button.pressed.connect(enter_next_map)
	choices.add_child(yes_button)
	var no_button: Button = Button.new()
	no_button.text = "아니오"
	no_button.custom_minimum_size = Vector2(120, 48)
	no_button.pressed.connect(close_portal_prompt)
	choices.add_child(no_button)
	portal_box.add_child(choices)
	portal_prompt.add_child(portal_box)
	layer.add_child(portal_prompt)
	var help: Label = Label.new()
	help.text = "WASD  MOVE     SHIFT  RUN (GROUND) / DOWN (FLY 4.2)     F  FLY     E  DRAW SWORD     SPACE  UP/JUMP     CLICK  SLASH     ESC  RELEASE MOUSE"
	help.position = Vector2(24, 682)
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color("d6d0ba"))
	help.add_theme_color_override("font_outline_color", Color("090a0b"))
	help.add_theme_constant_override("outline_size", 4)
	layer.add_child(help)
	add_child(layer)

func _input(event: InputEvent) -> void:
	if game_over or game_won:
		if event is InputEventKey and event.keycode == KEY_R and event.pressed and not event.echo:
			restart_scene()
		return
	if portal_prompt.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ENTER:
				enter_next_map()
			elif event.keycode == KEY_ESCAPE:
				close_portal_prompt()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0025
		pitch = clampf(pitch - event.relative.y * 0.0025, -1.25, 1.25)
		player.rotation.y = yaw
		camera.rotation.x = pitch
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		fly_mode = not fly_mode
		player.velocity.y = 0.0
	if event is InputEventKey and event.keycode == KEY_E and event.pressed and not event.echo:
		choose_nearby_weapon()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func end_game() -> void:
	if game_over or game_won:
		return
	game_over = true
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	portal_prompt.visible = false
	weapon_prompt.visible = false
	outcome_label.text = "GAME OVER"
	outcome_label.visible = true
	restart_button.visible = true

func end_victory() -> void:
	if game_over or game_won:
		return
	game_won = true
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	portal_prompt.visible = false
	weapon_prompt.visible = false
	outcome_label.text = "THE END"
	outcome_label.visible = true
	restart_button.visible = true

func restart_scene() -> void:
	# Victory restart intentionally begins a brand-new game. Game-over restart revives
	# on the current map and keeps only the earned sword state.
	if game_won:
		get_tree().reload_current_scene()
		return
	respawn_current_map()

func respawn_current_map() -> void:
	game_over = false
	health = MAX_HEALTH
	damage_cooldown = 0.0
	damage_flash = 0.0
	swing_time = 0.0
	swing_cooldown = 0.0
	footstep_timer = 0.0
	jump_was_pressed = false
	fly_mode = false
	yaw = 0.0
	pitch = 0.0
	portal_active = false
	portal_dismissed = false
	portal_position = Vector3.ZERO
	health_pickup_active = false
	sword_chest_active = false
	traps.clear()
	wall_traps.clear()
	enemies.clear()
	clown_projectiles.clear()
	portal_prompt.visible = false
	weapon_prompt.visible = false
	outcome_label.visible = false
	restart_button.visible = false
	hurt_overlay.color = Color(0.78, 0.025, 0.015, 0.0)
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = Node3D.new()
	add_child(world_root)
	set_map_two_ambience(map_index == 1)
	build_dungeon()
	player.position = Vector3(2.0 * CELL, 1.05, 1.0 * CELL)
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	camera.rotation.x = pitch
	sword.visible = sword_owned
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func open_portal_prompt() -> void:
	if game_over or game_won or portal_prompt.visible or portal_dismissed:
		return
	portal_prompt.visible = true
	weapon_prompt.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_portal_prompt() -> void:
	if not portal_prompt.visible:
		return
	portal_prompt.visible = false
	portal_dismissed = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func enter_next_map() -> void:
	if map_index != 0:
		return
	play_world_sfx("portal")
	portal_prompt.visible = false
	portal_active = false
	portal_dismissed = false
	sword_chest_active = false
	weapon_prompt.visible = false
	traps.clear()
	wall_traps.clear()
	map_index = 1
	active_map = MAP_TWO
	set_map_two_ambience(true)
	enemies.clear()
	world_root.queue_free()
	world_root = Node3D.new()
	add_child(world_root)
	build_dungeon()
	player.position = Vector3(2.0 * CELL, 1.05, 1.0 * CELL)
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if game_over or game_won:
		return
	update_map_two_ambience(delta)

func _physics_process(delta: float) -> void:
	if game_over or game_won or portal_prompt.visible:
		return
	# Keyboard movement must keep working even when the editor releases the mouse.
	# Mouse capture only controls whether mouse motion rotates the camera.
	var input_vec: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A): input_vec.x -= 1
	if Input.is_physical_key_pressed(KEY_D): input_vec.x += 1
	if Input.is_physical_key_pressed(KEY_W): input_vec.y -= 1
	if Input.is_physical_key_pressed(KEY_S): input_vec.y += 1
	# `sprint` is a physical Shift Input Map action; it runs on foot and descends in flight.
	var is_running: bool = not fly_mode and Input.is_action_pressed("sprint")
	var move_speed: float = FLY_SPEED if fly_mode else (SPRINT_SPEED if is_running else WALK_SPEED)
	var direction: Vector3 = (player.global_transform.basis * Vector3(input_vec.x, 0, input_vec.y)).normalized()
	player.velocity.x = direction.x * move_speed
	player.velocity.z = direction.z * move_speed
	var jump_pressed: bool = Input.is_physical_key_pressed(KEY_SPACE)
	if fly_mode:
		var fly_vertical: float = 0.0
		if jump_pressed:
			fly_vertical += FLY_SPEED
		if Input.is_action_pressed("sprint"):
			fly_vertical -= FLY_SPEED
		player.velocity.y = fly_vertical
	elif not player.is_on_floor():
		player.velocity.y -= 20.0 * delta
	elif jump_pressed and not jump_was_pressed:
		player.velocity.y = 7.0
	else:
		player.velocity.y = -0.1
	jump_was_pressed = jump_pressed
	player.move_and_slide()
	if not fly_mode and player.is_on_floor() and input_vec.length_squared() > 0.01:
		footstep_timer -= delta
		if footstep_timer <= 0.0:
			play_footstep_tone()
			footstep_timer = 0.34 if is_running else 0.56
	else:
		footstep_timer = 0.0
	damage_flash = maxf(0.0, damage_flash - delta * 3.4)

	swing_time = maxf(0.0, swing_time - delta)
	swing_cooldown = maxf(0.0, swing_cooldown - delta)
	if sword_owned and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and swing_cooldown <= 0.0:
		swing_time = SWING_DURATION
		swing_cooldown = 0.36
		attack()
		play_sword_swing_tone()
		if game_won:
			return
	var idle_bob: float = sin(Time.get_ticks_msec() * 0.004) * 0.018
	var base_sword_position: Vector3 = Vector3(0.42, -0.36 + idle_bob, -1.25)
	var sword_position: Vector3 = base_sword_position
	var sword_rotation: Vector3 = Vector3.ZERO
	if swing_time > 0.0:
		var swing_progress: float = 1.0 - swing_time / SWING_DURATION
		if swing_progress < 0.20:
			# Clear right/below wind-up: the blade is visibly pulled away before the swing.
			var windup: float = sin(swing_progress / 0.20 * PI * 0.5)
			sword_position = base_sword_position.lerp(Vector3(0.82, -0.64, -1.13), windup)
			sword_rotation = Vector3(0.0, 24.0 * windup, -70.0 * windup)
		elif swing_progress < 0.74:
			# Broad horizontal cut across the view. X sweep and roll carry the motion;
			# Z changes only slightly so it reads as a slash rather than a thrust.
			var slash: float = sin((swing_progress - 0.20) / 0.54 * PI * 0.5)
			sword_position = Vector3(lerpf(0.82, -0.58, slash), lerpf(-0.64, -0.10, slash), lerpf(-1.13, -1.32, slash))
			sword_rotation = Vector3(0.0, lerpf(24.0, -18.0, slash), lerpf(-70.0, 96.0, slash))
		else:
			# Hold the left/up follow-through briefly, then return to the right-hand idle.
			var recover: float = sin((swing_progress - 0.74) / 0.26 * PI * 0.5)
			sword_position = Vector3(-0.58, -0.10, -1.32).lerp(base_sword_position, recover)
			sword_rotation = Vector3(0.0, lerpf(-18.0, 0.0, recover), lerpf(96.0, 0.0, recover))
	sword.position = sword_position
	sword.rotation_degrees = sword_rotation

	damage_cooldown = maxf(0.0, damage_cooldown - delta)
	var enemy_touching: bool = false
	var ghost_nearby: bool = false
	ghost_cue_timer = maxf(0.0, ghost_cue_timer - delta)
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var enemy_body: CharacterBody3D = enemy as CharacterBody3D
		var flat: Vector3 = player.position - enemy.position
		flat.y = 0
		if enemy_body.get_meta("is_3d_enemy", false) and flat.length_squared() > 0.01:
			enemy_body.look_at(Vector3(player.position.x, enemy_body.position.y, player.position.z), Vector3.UP)
		if enemy_body.get_meta("is_ghost", false) and flat.length() < 4.8:
			ghost_nearby = true
		if enemy_body.get_meta("is_clown", false):
			var clown_distance: float = flat.length()
			var clown_direction: Vector3 = flat.normalized() if flat.length_squared() > 0.01 else Vector3.ZERO
			var ranged_cooldown: float = float(enemy_body.get_meta("ranged_cooldown", 0.0)) - delta
			var vulnerable_time: float = maxf(0.0, float(enemy_body.get_meta("vulnerable_time", 0.0)) - delta)
			if vulnerable_time > 0.0:
				enemy_body.velocity.x = 0.0
				enemy_body.velocity.z = 0.0
				update_boss_vulnerability_visual(enemy_body, true)
			else:
				update_boss_vulnerability_visual(enemy_body, false)
				if clown_distance < 5.0:
					enemy_body.velocity.x = -clown_direction.x * 1.05
					enemy_body.velocity.z = -clown_direction.z * 1.05
				elif clown_distance > 7.0:
					enemy_body.velocity.x = clown_direction.x * 1.05
					enemy_body.velocity.z = clown_direction.z * 1.05
				else:
					enemy_body.velocity.x = 0.0
					enemy_body.velocity.z = 0.0
				var shot_target: Vector3 = player.global_position + Vector3(0, 0.55, 0)
				if ranged_cooldown <= 0.0 and clown_distance < 14.0:
					var shots_fired: int = create_clown_volley(enemy_body, shot_target)
					if shots_fired > 0:
						ranged_cooldown = 1.05
						vulnerable_time = 0.90
						enemy_body.velocity.x = 0.0
						enemy_body.velocity.z = 0.0
			enemy_body.set_meta("ranged_cooldown", ranged_cooldown)
			enemy_body.set_meta("vulnerable_time", vulnerable_time)
		elif flat.length() < 40.0 and flat.length_squared() > 0.01:
			var chase_direction: Vector3 = flat.normalized()
			enemy_body.velocity.x = chase_direction.x * 1.15
			enemy_body.velocity.z = chase_direction.z * 1.15
		else:
			enemy_body.velocity.x = 0.0
			enemy_body.velocity.z = 0.0
		if enemy_body.get_meta("is_ghost", false):
			var hover_phase: float = float(enemy_body.get_meta("hover_phase", 0.0))
			enemy_body.position.y = 0.24 + sin(Time.get_ticks_msec() * 0.0032 + hover_phase) * 0.075
			enemy_body.velocity.y = 0.0
		elif not enemy_body.is_on_floor():
			enemy_body.velocity.y -= 20.0 * delta
		else:
			enemy_body.velocity.y = -0.1
		enemy_body.move_and_slide()
		if not enemy_body.get_meta("is_clown", false) and flat.length() < 1.0:
			enemy_touching = true
	if enemy_touching:
		apply_damage(8.0)
	if ghost_nearby and ghost_cue_timer <= 0.0:
		play_enemy_sfx("ghost")
		ghost_cue_timer = ambience_rng.randf_range(2.8, 5.2)
	update_clown_projectiles(delta)
	update_health_pickup(delta)
	update_traps(delta)
	update_wall_traps(delta)
	update_sword_chest()
	var shake: float = damage_flash * 0.035
	var shake_clock: float = Time.get_ticks_msec() * 0.045
	camera.position = Vector3(sin(shake_clock) * shake, 0.52 + cos(shake_clock * 1.7) * shake, 0)
	hurt_overlay.color = Color(0.78, 0.025, 0.015, damage_flash * 0.34)
	var health_ratio: float = clampf(health / MAX_HEALTH, 0.0, 1.0)
	heart_fill.size.x = 170.0 * health_ratio
	var movement_status: String = "FLY 4.2 (SHIFT DOWN)" if fly_mode else ("RUN 5.2" if is_running else "WALK 2.8")
	status.text = "HEALTH %02d / %02d  |  %s  |  EXPLORE THE DUNGEON" % [int(maxf(0, health)), int(MAX_HEALTH), movement_status]
	if health <= 0.0:
		end_game()
	elif portal_active:
		var portal_distance: float = player.position.distance_to(portal_position)
		if portal_dismissed and portal_distance >= PORTAL_REARM_DISTANCE:
			portal_dismissed = false
		elif not portal_dismissed and portal_distance < PORTAL_TRIGGER_DISTANCE:
			open_portal_prompt()

func attack() -> void:
	if not sword_owned:
		return
	var hit_confirmed: bool = false
	for enemy in enemies:
		if not is_instance_valid(enemy): continue
		var to_enemy: Vector3 = enemy.position - player.position
		to_enemy.y = 0
		var forward: Vector3 = -player.global_transform.basis.z
		if to_enemy.length() < 2.2 and forward.dot(to_enemy.normalized()) > 0.35:
			hit_confirmed = true
			if enemy.get_meta("is_boss", false):
				var boss_health: float = float(enemy.get_meta("boss_health", 0.0)) - SWORD_DAMAGE
				if boss_health <= 0.0:
					enemy.queue_free()
					end_victory()
				else:
					enemy.set_meta("boss_health", boss_health)
			else:
				enemy.queue_free()
	if hit_confirmed:
		play_enemy_sfx("blade_hit")
