extends StaticBody3D

var last_position = [Vector2(0,-50),Vector2(0,-50)]

var C_LEFT = Color()
var C_RIGHT = Color()

func _ready():
	$Node3D/cutFloor.material_override.albedo_texture = $SubViewport.get_texture()
	$Node3D/cutFloor.material_override.emission_texture = $SubViewport.get_texture()

func update_colors(COLOR_LEFT,COLOR_RIGHT):
	C_LEFT = COLOR_LEFT
	C_RIGHT = COLOR_RIGHT
	$SubViewport/ColorRect/burn_l.modulate = C_LEFT*6
	$SubViewport/ColorRect/burn_r.modulate = C_RIGHT*6
	
var is_out = [0,0]
func burn_mark(position=Vector3(0,0,-50),type=0):
	var burn_mark_sprite
	var burn_mark_sprite_long
	if type == 0:
		burn_mark_sprite = $SubViewport/ColorRect/burn_l
		burn_mark_sprite_long = $SubViewport/ColorRect/burn_l/sprite
	elif type == 1:
		burn_mark_sprite = $SubViewport/ColorRect/burn_r
		burn_mark_sprite_long = $SubViewport/ColorRect/burn_r/sprite
	else:
		return
	var was_out = !burn_mark_sprite.visible
	burn_mark_sprite.visible = true
	is_out[type] = 0
	
	var newpos = Vector2(
		(position.x+1)*256,
		position.z*256
	)
	
	burn_mark_sprite.position = newpos
	
	burn_mark_sprite.rotation = newpos.angle_to_point(last_position[type])
	burn_mark_sprite.rotation_degrees += 180
	var dist = last_position[type].distance_to(newpos)
	if dist > 12 and not was_out:
		burn_mark_sprite_long.size.x = dist+12
	else:
		burn_mark_sprite_long.size.x = 24
	
	last_position[type] = newpos

func _process(delta):
	if is_out[0] == 1:
		$SubViewport/ColorRect/burn_l.visible = false
	if is_out[1] == 1:
		$SubViewport/ColorRect/burn_r.visible = false
	is_out = [1,1]

func _on_timer_clear_timeout():
	$SubViewport/ColorRect.self_modulate.a = 1
	await get_tree().process_frame
	$SubViewport/ColorRect.self_modulate.a = 0
	$TimerClear.start()
