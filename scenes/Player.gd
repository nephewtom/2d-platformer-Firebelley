extends KinematicBody2D

signal died
var playerDeathScene = preload("res://scenes/PlayerDeath.tscn")
var footstepParticles = preload("res://scenes/FootstepParticles.tscn")

enum State { NORMAL, DASHING, INPUT_DISABLED }

export (int, LAYERS_2D_PHYSICS) var dashHazardMask = 0

var gravity = 1000
var velocity = Vector2.ZERO
var maxHorizontalSpeed = 140
var maxDashSpeed = 500
var mixDashSpeed = 200
var horizontalAcceleration = 2000
var jumpSpeed = 300
var jumpTerminationMultiplier = 4
var hasDoubleJump = false
var hasDash = false
var currentState = State.NORMAL
var isStateNew = true
var defaultHazardMask = 0
var isDying = false

# Called when the node enters the scene tree for the first time.
func _ready():
	$HazardArea.connect("area_entered", self, "on_hazard_area_entered")
	$AnimatedSprite.connect("frame_changed", self, "on_animated_sprite_frame_changed")
	defaultHazardMask = $HazardArea.collision_mask
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	match currentState:
		State.NORMAL:
			process_normal(delta)
		State.DASHING:
			process_dash(delta)
		State.INPUT_DISABLED:
			process_input_disabled(delta)
			
	isStateNew = false

func change_state(newState):
	currentState = newState
	isStateNew = true

func process_normal(delta):	
	if (isStateNew):
		$DashParticles.emitting = false
		$DashArea/CollisionShape2D.disabled = true
		$HazardArea.collision_mask = defaultHazardMask
	
	var moveVector = get_movement_vector()
	
	velocity.x += moveVector.x * horizontalAcceleration * delta
	if (moveVector.x == 0):
		velocity.x = lerp(0, velocity.x, pow(2, -40 * delta))
	
	velocity.x = clamp(velocity.x, -maxHorizontalSpeed, maxHorizontalSpeed)
	
	if (moveVector.y < 0 and (is_on_floor() or !$CoyoteTimer.is_stopped() or hasDoubleJump)):
		velocity.y = moveVector.y * jumpSpeed
		if (!is_on_floor() and $CoyoteTimer.is_stopped()):
			$"/root/Helpers".apply_camera_shake(.75)
			hasDoubleJump = false
		$CoyoteTimer.stop()
			
	
	if (velocity.y < 0 and !Input.is_action_pressed("jump")):
		velocity.y += gravity * jumpTerminationMultiplier * delta
	else:
		velocity.y += gravity * delta
	
	var wasOnFloor = is_on_floor()
	velocity = move_and_slide(velocity, Vector2.UP)
	
	if (wasOnFloor and !is_on_floor()):
		$CoyoteTimer.start()
	
	if (!wasOnFloor and is_on_floor() and !isStateNew):
		spawn_footsteps(1.5)
	
	if (is_on_floor()):
		hasDoubleJump = true
		hasDash = true
		
	if (hasDash and Input.is_action_just_pressed("dash")):
		call_deferred("change_state", State.DASHING)
		hasDash = false
		
	update_animation()

func process_dash(delta):
	if (isStateNew):
		$DashAudioPlayer.play()
		$DashParticles.emitting = true
		$"/root/Helpers".apply_camera_shake(.75)
		$DashArea/CollisionShape2D.disabled = false
		$AnimatedSprite.play("jump")
		$HazardArea.collision_mask = dashHazardMask
		
		var moveVector = get_movement_vector()
		var velocityMod = 1
		if (moveVector.x != 0):
			velocityMod = sign(moveVector.x)
		else:
			velocityMod = 1 if $AnimatedSprite.flip_h else -1
			
		velocity = Vector2(maxDashSpeed * velocityMod, 0)
		
	velocity = move_and_slide(velocity, Vector2.UP)
	velocity.x = lerp(0, velocity.x, pow(2, -8 * delta))
	
	if (abs(velocity.x) < mixDashSpeed):
		call_deferred("change_state", State.NORMAL)

func process_input_disabled(delta):
	velocity.x = lerp(0, velocity.x, pow(2, -40 * delta))
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector2.UP)
		
func get_movement_vector():
	if (isStateNew):
		$AnimatedSprite.play("idle")
		
	var moveVector = Vector2.ZERO
	moveVector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	moveVector.y = -1 if Input.is_action_just_pressed("jump") else 0	
	return moveVector

func update_animation():
	var moveVec = get_movement_vector()
	
	if (not is_on_floor()):
		$AnimatedSprite.play("jump")
	elif (moveVec.x != 0):
		$AnimatedSprite.play("run")
	else:
		$AnimatedSprite.play("idle")
		
	if (moveVec.x !=0):
		$AnimatedSprite.flip_h = true if moveVec.x > 0 else false

func kill():
	if (isDying):
		return
		
	isDying = true
	var playerDeathInstance = playerDeathScene.instance()
	playerDeathInstance.velocity = velocity
	get_parent().add_child_below_node(self, playerDeathInstance)
	playerDeathInstance.global_position = global_position
	emit_signal("died")
	
func spawn_footsteps(scale = 1):
		var footstep = footstepParticles.instance()
		get_parent().add_child(footstep)
		footstep.scale = Vector2.ONE * scale
		footstep.global_position = global_position
		$FootstepAudioPlayer.play()
	
func disable_player_input():
	change_state(State.INPUT_DISABLED)
	
func on_hazard_area_entered(_area2d):
	$"/root/Helpers".apply_camera_shake(1)
	call_deferred("kill")
	
func on_animated_sprite_frame_changed():
	if ($AnimatedSprite.animation == "run" and $AnimatedSprite.frame == 0):
		spawn_footsteps()
