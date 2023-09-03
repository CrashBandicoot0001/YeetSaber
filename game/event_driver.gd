extends Node3D

var _spectrum = null;
var _spectrum_nodes = [];
@export var game_path: NodePath;
var game;

var ring_rot_speed = 0.0;
var ring_rot_inv_dir = false;

@export var disabled = false

func _ready():
	if not game:
		game = get_node(game_path);
	_setup_level();

func _process(delta):
	_update_level(delta);
	
# update the level animations
func _update_level(dt):
	var VU_COUNT = _spectrum_nodes.size();
	var FREQ_MAX = 11050.0
	var MIN_DB = 60.0

	var prev_hz = 100
	for i in range(1,VU_COUNT+1):
		var hz = i * FREQ_MAX / VU_COUNT;
		var f = _spectrum.get_magnitude_for_frequency_range(prev_hz,hz)
		var energy = clamp((MIN_DB + linear_to_db(f.length()))/MIN_DB,0,1)
		
		if _spectrum_nodes[i-1].position.y < energy * 10.0:
			_spectrum_nodes[i-1].position.y = min(_spectrum_nodes[i-1].position.y+0.2,energy * 10.0);
		else:
			_spectrum_nodes[i-1].position.y -= 0.08;

		prev_hz = hz
		
	#procces ring rotations
	if ring_rot_speed > 0:
		for ring in $Level/rings.get_children():
			if ring is Node3D:
				var rot = ring_rot_speed
				if ring_rot_inv_dir: rot *= -1
				ring.rotate_z((rot * dt) * (float(ring.get_index()+1)/5))
			

# create the level data that is displayed
func _setup_level():
	# create a specrum analyzer
	AudioServer.add_bus_effect(0, AudioEffectSpectrumAnalyzer.new());
	_spectrum = AudioServer.get_bus_effect_instance(0,0);
	# and create some cubes to display it in the level (updated in _update_level(dt))
	var s = $Level/SpectrumBar;
	_spectrum_nodes.push_back(s);
	for  i in range(0, 7):
		s = s.duplicate()
		$Level.add_child(s);
		s.position.x += 2.0;
		_spectrum_nodes.push_back(s);
		
	update_colors()

func update_colors():
	for i in [0,2,3]:
		change_light_color(i,game.COLOR_LEFT)
	for i in [1,4]:
		change_light_color(i,game.COLOR_RIGHT)
		
func set_all_off():
	if not disabled:
		for i in [0,1,2,3,4]:
			change_light_color(i,-1)
	else:
		update_colors()
		for i in [1,2,3]:
			change_light_color(i,-1)
		$Level/rings.visible = false
func set_all_on():
		update_colors()
		$Level/rings.visible = true

func procces_event(data,beat):
	if disabled: return
#	print(data)
	if int(data._type) in [0,1,2,3,4]:
		match int(data._value):
			0:
				change_light_color(data._type,-1)
			1:
				change_light_color(data._type,game.COLOR_RIGHT)
			2:
				change_light_color(data._type,game.COLOR_RIGHT,1)
			3:
				change_light_color(data._type,game.COLOR_RIGHT,2)
			5:
				change_light_color(data._type,game.COLOR_LEFT)
			6:
				change_light_color(data._type,game.COLOR_LEFT,1)
			7:
				change_light_color(data._type,game.COLOR_LEFT,2)
	else:
		match int(data._type):
			8:
				var ringtween = $Level/rings.create_tween()
				ring_rot_inv_dir = bool(randi()%2)
				ringtween.set_trans(Tween.TRANS_QUAD)
				ringtween.set_ease(Tween.EASE_OUT)
				ringtween.tween_property(self,"ring_rot_speed",0.0, 2).from(3.0)
				ringtween.play()
			9:
				$Level/rings/AnimationPlayer.stop(false)
				if $Level/rings/AnimationPlayer.current_animation == "out":
					$Level/rings/AnimationPlayer.play("in")
				else:
					$Level/rings/AnimationPlayer.play("out")
					
			12:
				var val = float(data._value)/8
				$Level/t2/AnimationPlayer.speed_scale = val
				$Level/t2/AnimationPlayer.seek(randf_range(0,$Level/t2/AnimationPlayer.current_animation_length),true)
			13:
				var val = float(data._value)/8
				$Level/t3/AnimationPlayer.speed_scale = val
				$Level/t3/AnimationPlayer.seek(randf_range(0,$Level/t3/AnimationPlayer.current_animation_length),true)
	
func change_light_color(type,color=-1,transition_mode=0):
	var group : Node3D
	var material = []
	var shader = []
	var tween : Tween
	match int(type):
		0:
			group = $Level/t0
			material = [$Level/t0/laser1/Bar7.material_override]
			tween = $Level/t0.create_tween()
		1:
			group = $Level/t1
			material = [$Level/t1/Bar7.material_override]
			tween = $Level/t1.create_tween()
		2:
			group = $Level/t2
			material = [$Level/t2/laser1/Bar7.material_override]
			tween = $Level/t2.create_tween()
		3:
			group = $Level/t3
			material = [$Level/t3/laser1/Bar7.material_override]
			tween = $Level/t3.create_tween()
		4:
			group = $Level/t4
			material = [$Level/t4/Bar1.material_override, $Level/floor.material_override]
			shader = [$wall_material_holder.material_override]
			tween = $Level/t4.create_tween()
	
	if not color is Color:
		for m in material:
			m.albedo_color = Color.BLACK
		#tween.stop_all() ###
		$Level/Sphere.material_override.set_shader_parameter("bg_%d_intensity"%int(type),0.0)
		group.visible = false
		return
	else:
		for m in shader:
			m.set_shader_parameter("albedo_color",color)
		$Level/Sphere.material_override.set_shader_parameter("bg_%d_tint"%int(type),color)
	
	match transition_mode:
		0:
			for m in material:
				m.albedo_color = color
			$Level/Sphere.material_override.set_shader_parameter("bg_%d_intensity"%int(type),color.v)
			group.visible = true
		1:
			tween.set_parallel()
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_OUT)
			for m in material:
				tween.tween_property(m, "albedo_color", color, 0.3).from(color*3)
			tween.tween_method(_on_Tween_tween_step.bind(int(type)), color*3, color, 0.3)
			tween.play()
			group.visible = true
		2:
			tween.set_parallel()
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_IN)
			for m in material:
				tween.tween_property(m, "albedo_color", Color(0,0,0), 1).from(color*3)
			tween.tween_method(_on_Tween_tween_step.bind(int(type)), color*3, Color(0,0,0), 1)
			group.visible = true
			tween.play()
			await tween.finished
			if material[0].albedo_color == Color(0,0,0):
				group.visible = false
			

func _on_Tween_tween_step(value : Color, id):
	if id == null: return
	$Level/Sphere.material_override.set_shader_parameter("bg_%d_intensity"%id,value.v)










