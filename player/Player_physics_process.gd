extends RigidBody


onready var body: = $Body
onready var collisionShape: = $CollisionShape
onready var camera: = $Body/Camera
onready var JumpBuffer: = $JumperBuffer
onready var GroundCheck: = $GroundCheck
onready var label: = $CanvasLayer/Label
onready var draw: = $"Draw"

var forward:Vector3
var right:Vector3

var ground_layer: = 1

#Movement
var delta: = 0.0
var speed: = 60.0
var max_speed: = 5.0
var gravity_impulse: = 30.0
var is_grounded: = false
var threshold: = 0.01
var max_angle: = 45.0/90.0	#easy to check against normals y value
var counterMovement: = 0.01	#0.175
var state: PhysicsDirectBodyState	#save a reference so no need to pass in functions

#Crouch & Slide
#var slideForce: = 400
#var slideCounterMovement: = 0.2

#Jumping
var jump_impulse: = 14.0
var jump_count: = 0
var max_jumps: = 1
var is_jumping: = false 	#jump logic deviation from DaviTutorials
var jump_release: = jump_impulse * 0.25

#Input
var btn_right: = 0.0
var btn_left: = 0.0
var btn_up: = 0.0
var btn_down: = 0.0
var dir: = Vector2.ZERO
var x: = 0.0
var y: = 0.0
var jump: = false
var sprinting: = false
var crouching: = false

#Sliding
var ground_normal: = Vector3.UP
var wallNormalVector:Vector3


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

func _physics_process(_delta:float)->void:
	forward = -body.global_transform.basis.z.slide(ground_normal)
	right = body.global_transform.basis.x.slide(ground_normal)
	
	draw.point = right*2.0										#Debugg draw ImmediateGeometry line
	dir.x = btn_right - btn_left
	dir.y = btn_up - btn_down
	delta = _delta
	movement()
	gravity_logic()
	collision_check()	#ground check


func movement()->void:
	var mag:Vector2 = FindVelRelativeToLook()
	CounterMovement(mag)    #x & y is global variable
		
	#If speed is larger than max_speed, cancel out the input so you don't go over max speed
	if abs(mag.x) > max_speed:
		dir.x = 0
	if abs(mag.y) > max_speed:
		dir.y = 0
	
	var multiplier: = Vector2(1.0, 1.0)
	if !is_grounded:
		multiplier = Vector2(0.5, 0.5)
	
	#Apply forces to move player
	apply_central_impulse(forward * dir.y * speed * delta * multiplier.x * multiplier.y)
	apply_central_impulse(right * dir.x * speed * delta * multiplier.x)

func FindVelRelativeToLook()->Vector2:
	var lookDir = Vector2(forward.x, forward.z)
	var moveDir = Vector2(linear_velocity.x, linear_velocity.z)
	var u = lookDir.angle_to(moveDir)
	var v = deg2rad(90) - u
	var magnitude = moveDir.length()
	return Vector2(magnitude * cos(v), magnitude * cos(u))

func CounterMovement(mag:Vector2)->void:
	#Counter movement
	if (abs(mag.x) > threshold && abs(dir.x) < 0.05) || (mag.x < -threshold && dir.x > 0) || (mag.x > threshold && dir.x < 0):
		apply_central_impulse(speed * right * delta * -mag.x * counterMovement)
	if (abs(mag.y) > threshold && abs(dir.y) < 0.05) || (mag.y < -threshold && dir.y > 0) || (mag.y > threshold && dir.y < 0):
		apply_central_impulse(speed * forward * delta * -mag.y * counterMovement)
	
	#Limit diagonal running. This will also cause a full stop if sliding fast and un-crouching, so not optimal
	if Vector2(linear_velocity.x, linear_velocity.z).length() > max_speed:
		var fallSpeed = linear_velocity.y
		var n: = linear_velocity.normalized() * max_speed
		var limit: = Vector3(n.x, fallSpeed, n.z)
		apply_central_impulse(limit - linear_velocity)

func gravity_logic()->void:
	if is_grounded:
		apply_gravity()
		if is_jumping:
			jump = false
			is_jumping = false
		elif !is_jumping && jump:
			Jump()
	else:
		apply_gravity()
		if is_jumping:
			if !jump:
				is_jumping = false
				if linear_velocity.y > jump_release:
					apply_central_impulse(Vector3(0.0, (jump_release) - linear_velocity.y, 0.0))
		else:
			if jump:
				if !JumpBuffer.is_stopped():
					Jump()
				elif jump_count < max_jumps:
					jump_count += 1
					Jump()
	

func apply_gravity()->void:
	apply_central_impulse(-ground_normal * delta * gravity_impulse)

func Jump()->void:
	apply_central_impulse(Vector3(0.0, (jump_impulse * 0.75) - linear_velocity.y, 0.0))
	apply_central_impulse(ground_normal * jump_impulse * 0.25)
	is_jumping = true
	is_grounded = false
	ground_normal = Vector3.UP
	JumpBuffer.stop()
	GroundCheck.start()
	jumping()

func collision_check()->void:
	var new_is_grounded: = false
	if GroundCheck.is_stopped():
		var space_state: = get_world().direct_space_state
		var shape: = PhysicsShapeQueryParameters.new()
		shape.transform = collisionShape.global_transform
		shape.shape_rid = collisionShape.shape.get_rid()
		shape.collision_mask = 1
		var result: = space_state.get_rest_info(shape)
		if result:											#if shape is colliding
			ground_normal = result.normal
			new_is_grounded = true
		else:												#Check using raycast down
			var pos: = global_transform.origin
			var hit:Dictionary = space_state.intersect_ray(pos, pos+Vector3(0.0, -0.1, 0.0), [], 1)
			if hit:
				if hit.normal.y >= 0.5:
					ground_normal = hit.normal
					new_is_grounded = true
					var dist:Vector3 = hit.position - pos
					apply_central_impulse(dist)
	
	if is_grounded && !new_is_grounded:
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






