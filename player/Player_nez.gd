extends RigidBody

export (float) var run_force = 20.0
export (float) var air_run_force = 10.0
export (float) var max_speed = 8.0
export (float) var stop_ratio = 2.0
export (float) var jump_impulse = 800.0
export (float) var slide_reduction = 20.0
export (Vector3) var extra_gravity = Vector3(0.0, -10.0, 0.0)
var traction: = 1.0
var is_grounded: = false

onready var body: = $Body
onready var camera: = $Body/Camera

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.mouse_movement(event)

func _integrate_forces(state: PhysicsDirectBodyState)->void:
	is_grounded = false
	for i in state.get_contact_count():
		is_grounded = state.get_contact_local_normal(i).y > 0.5
		
	#state.linear_velocity = state.linear_velocity.move_toward(Vector3(dir.x, state.linear_velocity.y, dir.z), acceleration * state.step)
	pass

func _physics_process(delta:float)->void:
	var forward:Vector3 = -body.transform.basis.z * (Input.get_action_strength("move_up") - Input.get_action_strength("move_down"))
	var side:Vector3 = body.transform.basis.x * (Input.get_action_strength("move_right") - Input.get_action_strength("move_left"))
	var direction:Vector3 = (side + forward).normalized()
	if direction.length() > 0.1:
		if Vector2(linear_velocity.x, linear_velocity.y).length() < max_speed:
			if is_grounded:
				add_central_force(direction*run_force)
			else:
				add_central_force(direction*air_run_force)
		updateFriction(Vector2(direction.x, direction.z))
	else:
		add_central_force(-linear_velocity*stop_ratio)
	if is_grounded:
		if Input.is_action_just_pressed("jump"):
			add_central_force(Vector3(0.0, jump_impulse, 0.0))
	else:
		add_central_force(extra_gravity)

func getLateralVelocity(dir:Vector2)->Vector2:
	var velocity: = Vector2(body.linear_velocity.x, body.linear_velocity.z)
	var forward: = dir.rotated(PI*0.5)
	return forward.dot(velocity) * forward

func getForwardVelocity(dir:Vector2)->Vector2:
	var velocity: = Vector2(body.linear_velocity.x, body.linear_velocity.z)
	return dir.dot(velocity) * dir

func updateFriction(dir:Vector2)->void:
	var impulse: = -getLateralVelocity(dir)
	var impulse_len: = impulse.length()
	if impulse_len > slide_reduction:
		impulse *= slide_reduction / impulse_len
	var side_force: = Vector3(impulse.x, 0.0, impulse.y) * traction
	add_central_force(side_force)
