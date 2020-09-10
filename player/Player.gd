extends RigidBody


onready var body: = $Body
onready var camera: = $Body/Camera

var forward:Vector3
var right:Vector3

#Movement
var moveSpeed: = 4500
var maxSpeed: = 20.0
var grounded: = false
var threshold: = 0.01
var maxSlopeAngle: = 45.0/90.0	#easy to check against normals y value
var counterMovement: = 0.175

#Crouch & Slide
var slideForce: = 400
var slideCounterMovement: = 0.2

#Jumping
var readyToJump = true
var jumpCooldown = 0.25
var jumpForce = 550.0

#Input
var x: = 0.0
var y: = 0.0
var jumping: = false
var sprinting: = false
var crouching: = false

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseMotion && Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera.mouse_movement(event)	#Camera deals with turning and looking

func _integrate_forces(state: PhysicsDirectBodyState)->void:
	forward = -body.transform.basis.z
	right = body.transform.basis.x
	
	grounded = false
	for i in state.get_contact_count():
		grounded = state.get_contact_local_normal(i).y > 0.5
	MyInput()
	movement(state.step)


func MyInput()->void:
	x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
	jumping = Input.is_action_pressed("jump")
	crouching = Input.is_action_pressed("crouch")
	
#    if Input.is_action_just_pressed("crouch"):
#        StartCrouch()   #not important now
#    if Input.is_action_just_released("crouch"):
#        StopCrouch()    #not important now

func movement(delta:float)->void:
	#Add extra gravity
	add_central_force(Vector3.DOWN * delta * 10)
	
	#Find actual velocity relative to where player is looking
	var mag:Vector2 = FindVelRelativeToLook()
	
	#Counteract sliding and sloppy movement
	CounterMovement(delta, mag)    #x & y is global variable
	
	#If holding jump && ready to jump, then jump
	if readyToJump && jumping:
		#Jump()
		pass
	
	#If sliding down a ramp, add force down so player stays grounded and also builds speed
	if crouching && grounded && readyToJump:
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
	if !grounded:
		multiplier = Vector2(0.5, 0.5)
	
	#Movement while sliding
	if grounded && crouching:
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
	if !grounded || jumping:
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
