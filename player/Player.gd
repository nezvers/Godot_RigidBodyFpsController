extends RigidBody


onready var body: = $Body
onready var camera: = $Body/Camera
onready var jumpBuffer: = $JumperBuffer

var forward:Vector3
var right:Vector3

var ground_layer: = 1

#Movement
var moveSpeed: = 4500
var maxSpeed: = 20.0
var is_grounded: = false
var cancellingis_grounded: = false
var threshold: = 0.01
var maxSlopeAngle: = 45.0/90.0	#easy to check against normals y value
var counterMovement: = 0.175
var gravity_force: = 3000.0

#Crouch & Slide
var slideForce: = 400
var slideCounterMovement: = 0.2

#Jumping
var readyToJump: = true
var jumpCooldown: = 0.25
var jumpForce: = 450.0
var jump_count: = 0
var max_jumps: = 2
var is_jumping: = false 	#jump logic deviation from DaviTutorials

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
var normalVector: = Vector3.UP
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
	elif event.is_action_pressed("crouch"):
		crouching = true
#        StartCrouch()   #not important now
	elif event.is_action_released("crouch"):
		crouching = false
#        StopCrouch()    #not important now
	

func _integrate_forces(state: PhysicsDirectBodyState)->void:
	forward = -body.transform.basis.z
	right = body.transform.basis.x
	x = btn_right - btn_left
	y = btn_up - btn_down
	CollisionCheck(state)
	movement(state.step)


func movement(delta:float)->void:
	#Add extra gravity
	add_central_force(Vector3.DOWN * delta * gravity_force)
	
	#Find actual velocity relative to where player is looking
	var mag:Vector2 = FindVelRelativeToLook()
	
	#Counteract sliding and sloppy movement
	CounterMovement(delta, mag)    #x & y is global variable
	
	#If holding jump && ready to jump, then jump
	if readyToJump && jump:
		Jump()
	
	#If sliding down a ramp, add force down so player stays is_grounded and also builds speed
	if crouching && is_grounded && readyToJump:
		add_central_force(Vector3.DOWN * delta * 3000)
		return
	
	#If speed is larger than maxspeed, cancel out the input so you don't go over max speed
	if abs(mag.x) > maxSpeed:
		x = 0
	if abs(mag.y) > maxSpeed:
		y = 0
	
	#Some multipliers
	var multiplier: = Vector2(1.0, 1.0)
	
	#Movement in air
	if !is_grounded:
		multiplier = Vector2(0.5, 0.5)
	
	#Movement while sliding
	if is_grounded && crouching:
		multiplier.y = 0.0
	
	#Apply forces to move player
	add_central_force(forward * y * moveSpeed * delta * multiplier.x * multiplier.y)
	add_central_force(right * x * moveSpeed * delta * multiplier.x)

func FindVelRelativeToLook()->Vector2:
	var lookDir = Vector2(forward.x, forward.z)
	var moveDir = Vector2(linear_velocity.x, linear_velocity.z)
	
	var u = lookDir.angle_to(moveDir)
	var v = deg2rad(90) - u
	
	var magnitude = moveDir.length()
	
	return Vector2(magnitude * cos(v), magnitude * cos(u))

func CounterMovement(delta:float, mag:Vector2)->void:
	if !is_grounded || jump:
		return
	
	#Slow down sliding
	if crouching:
		add_central_force(moveSpeed * delta * -linear_velocity.normalized() * slideCounterMovement)
		return
	
	#Counter movement
	if (abs(mag.x) > threshold && abs(x) < 0.05) || (mag.x < -threshold && x > 0) || (mag.x > threshold && x < 0):
		add_central_force(moveSpeed * right * delta * -mag.x * counterMovement)
	if (abs(mag.y) > threshold && abs(y) < 0.05) || (mag.y < -threshold && y > 0) || (mag.y > threshold && y < 0):
		add_central_force(moveSpeed * forward * delta * -mag.y * counterMovement)
	
	#Limit diagonal running. This will also cause a full stop if sliding fast and un-crouching, so not optimal
	# !!! because of last line all this code probably should be in _integrated_forces()
	if Vector2(linear_velocity.x, linear_velocity.z).length() > maxSpeed:
		var fallSpeed = linear_velocity.y
		var n: = linear_velocity.normalized() * maxSpeed
		linear_velocity = Vector3(n.x, fallSpeed, n.z)

func Jump()->void:
	if is_grounded && readyToJump:
		readyToJump = false
		
		#Add jump forces
		add_central_force(Vector3.UP * jumpForce * 1.5)
		add_central_force(normalVector * jumpForce * 0.5)
		
		#If jump while falling, reset y velocity.
		#Not sure yet about that section

func CollisionCheck(state: PhysicsDirectBodyState)->void:
	var new_is_grounded: = false
	for id in state.get_contact_count():
		if ground_layer == ground_layer & state.get_contact_collider_object(id).collision_mask:	#bitmask AND with ground layer to check if colliding against ground layer
			var normal = state.get_contact_local_normal(id)
			if normal.y > maxSlopeAngle:
				new_is_grounded = true
				readyToJump = true
	
	if is_grounded && !new_is_grounded:
		if !jump:
			jumpBuffer.start()
	elif !is_grounded && new_is_grounded:
		jump_count = 0
		landed()																#virtual method
	is_grounded = new_is_grounded


#CALLBACK METHODS
func landed()->void:
	pass







