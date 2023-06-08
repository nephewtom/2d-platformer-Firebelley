extends KinematicBody2D

var velocity = Vector2.ZERO
var gravity = 1000

func _ready():
	if (velocity.x > 0):
		$Visuals.scale = Vector2(-1, 1)

	$DeathSoundPlayer1.play()
	$DeathSoundPlayer2.play()
	$DeathSoundPlayer3.play()
func _process(delta):
	velocity.y += gravity * delta
	velocity = move_and_slide(velocity, Vector2.UP)
	
	if (is_on_floor()):
		velocity.x = lerp(0, velocity.x, pow(2, -1 * delta))
