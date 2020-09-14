extends RigidBody


onready var body: = $Body
onready var camera: = $Body/Camera
onready var JumpBuffer: = $JumperBuffer
onready var label: = $CanvasLayer/Label
onready var draw: = $Draw

var forward:Vector3
var right:Vector3

var ground_layer: = 1

#Movement
var delta: = 0.0
var moveSpeed: = 30.0
var maxSpeed: = 5.0
var is_grounded: = false
var threshold: = 0.01
var maxSlopeAngle: = 45.0/90.0	#easy to check against normals y value
var counterMovement: = 0.175
var gravity_force: = 60.0
var state: PhysicsDirectBodyState	#save a reference so no need to pass in functions

#Crouch & Slide
#var slideForce: = 400
#var slideCounterMovement: = 0.2

#Jumping
var jump_impulse: = 20.0
var jump_count: = 0
var max_jumps: = 1
var is_jumping: = false 	#jump logic deviation from DaviTutorials
var jump_release: = jump_impulse * 0.25

#Input
var btn_right: = 0.0
var btn_left: = 0.0
var btn_up: = 0.0
var btn_down: = 0.0
var x: = 0.0
var y: = 0.0
var jump: = false
var sprinting: = false
var crouching: = false

#Sliding
var ground_normal: = Vector3.UP
var wallNormalVector:Vector3

#func _process(_delta):
#	label.text = str(Performance.get_monitor(Performance.TIME_FPS))

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.mouse_movement(event)	#Camera deals with turning and looking
	elif event.is_action("move_right"):
		btn_right = Input.get_action_strength("move_right")
	elif event.is_action("move_left"):
		btn_left = Input.get_action_strength("move_left")
	elif event.is_action("move_up"):
		btn_up = Input.get_action_strength("move_up")
	elif event.is_action("move_down"):
		btn_down = Input.get_action_strength("move_down")
	elif event.is_action_pressed("jump"):
		jump = true
	elif event.is_action_released("jump"):
		jump = false	

func _integrate_forces(_state: PhysicsDirectBodyState)->void:
	forward = -body.global_transform.basis.z.slide(ground_normal)
	right = body.global_transform.basis.x.slide(ground_normal)
	
	draw.point = right*2.0										#Debugg draw ImmediateGeometry line
	x = btn_right - btn_left
	y = btn_up - btn_down
	state = _state
	delta = _state.step
	CollisionCheck()	#ground check
	gravity_logic()
	movement()


func movement()->void:
	var mag:Vector2 = FindVelRelativeToLook()
	CounterMovement(mag)    #x & y is global variable
		
	#If speed is larger than maxspeed, cancel out the input so you don't go over max speed
	if abs(mag.x) > maxSpeed:
		x = 0
	if abs(mag.y) > maxSpeed:
		y = 0
	
	var multiplier: = Vector2(1.0, 1.0)
	if !is_grounded:
		multiplier = Vector2(0.5, 0.5)
	
	#Apply forces to move player
	state.apply_central_impulse(forward * y * moveSpeed * delta * multiplier.x * multiplier.y)
	state.apply_central_impulse(right * x * moveSpeed * delta * multiplier.x)

func FindVelRelativeToLook()->Vector2:
	var lookDir = Vector2(forward.x, forward.z)
	var moveDir = Vector2(state.linear_velocity.x, state.linear_velocity.z)
	var u = lookDir.angle_to(moveDir)
	var v = deg2rad(90) - u
	var magnitude = moveDir.length()
	return Vector2(magnitude * cos(v), magnitude * cos(u))

func CounterMovement(mag:Vector2)->void:
	if !is_grounded || jump:
		return
		
	#Counter movement
	if (abs(mag.x) > threshold && abs(x) < 0.05) || (mag.x < -threshold && x > 0) || (mag.x > threshold && x < 0):
		state.apply_central_impulse(moveSpeed * right * delta * -mag.x * counterMovement)
	if (abs(mag.y) > threshold && abs(y) < 0.05) || (mag.y < -threshold && y > 0) || (mag.y > threshold && y < 0):
		state.apply_central_impulse(moveSpeed * forward * delta * -mag.y * counterMovement)
	
	#Limit diagonal running. This will also cause a full stop if sliding fast and un-crouching, so not optimal
	if Vector2(state.linear_velocity.x, state.linear_velocity.z).length() > maxSpeed:
		var fallSpeed = state.linear_velocity.y
		var n: = state.linear_velocity.normalized() * maxSpeed
		state.linear_velocity = Vector3(n.x, fallSpeed, n.z)

func gravity_logic()->void:
	if is_grounded:
		state.apply_central_impulse(-ground_normal * delta * gravity_force)
		if is_jumping:
			jump = false
			is_jumping = false
		elif !is_jumping && jump:
			Jump()
	else:
		state.apply_central_impulse(-ground_normal * delta * gravity_force)
		if is_jumping:
			if !jump:
				is_jumping = false
				if state.linear_velocity.y > jump_release:
					state.linear_velocity.y = jump_release
		else:
			if jump:
				if !JumpBuffer.is_stopped():
					Jump()
				elif jump_count < max_jumps:
					jump_count += 1
					Jump()
	state.linear_velocity.y = max(state.linear_velocity.y, -jump_impulse)

func Jump()->void:
	state.linear_velocity.y = jump_impulse * 0.75
	state.apply_central_impulse(ground_normal * jump_impulse * 0.25)
	is_jumping = true
	is_grounded = false
	ground_normal = Vector3.UP
	JumpBuffer.stop()
	jumping()

func CollisionCheck()->void:
	var new_is_grounded: = false
	for id in state.get_contact_count():
		if (ground_layer == ground_layer & state.get_contact_collider_object(id).collision_mask) && linear_velocity.y <= 0.01:
			var normal = state.get_contact_local_normal(id)
			if normal.y > maxSlopeAngle:
				new_is_grounded = true
				ground_normal = normal
	
	if is_grounded && !new_is_grounded:
		print("lost ground. Forward: ", forward)
		if !jump:
			JumpBuffer.start()
	elif !is_grounded && new_is_grounded:
		jump_count = 0
		landed()																#virtual method
	is_grounded = new_is_grounded
	if !is_grounded:
		ground_normal = Vector3.UP


#CALLBACK METHODS
func landed()->void:
	pass

func jumping()->void:
	pass






