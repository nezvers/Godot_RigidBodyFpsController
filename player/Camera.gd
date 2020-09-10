extends Camera

export (float, 0.001, 0.1) var mouse_sensitivity = 0.005
export (bool) var invert_x = false
export (bool) var invert_y = false

onready var body: = $".."
var max_angle: = PI * 0.5

func mouse_movement(event:InputEventMouseMotion)->void:
	if event.relative.x != 0:
		var dir = 1 if invert_x else -1
		body.rotate_object_local(Vector3.UP, dir * event.relative.x * mouse_sensitivity)
	if event.relative.y != 0:
			var dir = 1 if invert_y else -1
			var y_rotation = event.relative.y
			rotation.x = clamp(rotation.x + dir * y_rotation * mouse_sensitivity, -max_angle, max_angle)
