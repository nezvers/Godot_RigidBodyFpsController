# original - https://github.com/DaniDevy/FPS_Movement_Rigidbody
# IN PROCESS OF TRANSLATION
extends RigidBody

var x:float
var y:float
var moveSpeed: = 4500
var maxSpeed: = 20.0
var slideCounterMovement: = 0.2
var threshold: = 0.01
onready var body: = $Body   #child node used for rotation

func _unhandled_input(event:INputEvent)->void:
    #camera and turning logic HERE

func _integrate_forces(state:  PhysicsDirectBodyState)
    MyInput()
    movement(state.step)
    
func MyInput()->void:
    x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    y = Input.get_action_strength("move_up") - Input.get_action_strength("move_down")
    jumping = Input.is_action_pressd("jump")
    crouching = Input.is_action_pressed("crouch")
    
    if Input.is_action_just_pressed("crouch")
        StartCrouch()   #not important now
    if Input.is_action_just_released("crouch")
        StopCrouch()    #not important now


func movement(delta:float)->void:
    #Add extra gravity
    add_central_impulse(Vector3.DOWN * delta * 10)
    
    #Find actual velocity relative to where player is looking
    mag:Vector2 = FindVelRelativeToLook()
    xMag: = mag.x
    yMag: = mag.y
    
    #Counteract sliding and sloppy movement
    CounterMovement(delta, mag)    #x & y is global variable
    
    #If holding jump && ready to jump, then jump
    if readyToJump && jumping:
        Jump()
    
    #If sliding down a ramp, add force down so player stays grounded and also builds speed
    if crouching && grounded && readyToJump:
        add_central_impulse(Vector3.DOWN * delta * 3000)
        return
    
    #If speed is larger than maxspeed, cancel out the input so you don't go over max speed
    if abs(xMag) > maxSpeed:
        x = 0
    if abs(yMag) > maxSpeed:
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
    var forward: = -body.transform.basis.z
    var right: = body.transform.basis.x
    add_central_impulse(forward * y * moveSpeed * delta * multiplier.x * multiplier.y)
    add_central_impulse(right * x * moveSpeed * delta * multiplier.x)

func FindVelRelativeToLook()->Vector2:
    var forward: = -body.transform.basis.z   #Camera pointing default direction
    var lookDir = Vector2(forward.x, forward.z)
    var moveDir = Vector2(linear_velocity.x, linear_velocity.z)
    
    var u = lookDir.angle_to(moveDir)
    var v = deg2rad(90) - u
    
    var magnitude = moveDir.length()
    yMag = magnitude * cos(u)
    xMag = magnitude * cos(v)
    
    return Vector2(xMag, yMag)

func CounterMovement(delta:float, mag:Vector2)->void:
    if !grounded || jumping:
        return
    
    #Slow down sliding
    if crouching:
        add_central_impulse(moveSpeed * delta * -linear_velocity.normalized() * slideCounterMovement)
        return
    
    #Counter movement
    if (abs(mag.x) > threshold && abs(x) < 0.05) || (mag.x < -threshold && x > 0) || (mag.x > threshold && x < 0):
        var right: = body.transform.basis.x
        add_central_impulse(moveSpeed * right * delta * -mag.x * counterMovement)
    if (abs(mag.y) > threshold && abs(y) < 0.05) || (mag.y < -threshold && y > 0) || (mag.y > threshold && y < 0):
        var forward: = -body.transform.basis.z
        add_central_impulse(moveSpeed * forward * delta * -mag.y * counterMovement)
    
    #Limit diagonal running. This will also cause a full stop if sliding fast and un-crouching, so not optimal
    # !!! because of last line all this code probably should be in _integrated_forces()
    if Vector2(linear_velocity.x, linear_velocity.z).length() > maxSpeed:
        fallSpeed = linear_velocity.y
        v: = linear_velocity.normalized() * maxSpeed
        linear_velocity = Vector3(n.x, fallSpeed, n.z)
