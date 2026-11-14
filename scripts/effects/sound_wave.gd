class_name SoundWave
extends CharacterBody2D

signal bounced(position: Vector2, normal: Vector2, bounce_count: int)
signal expired

@export var speed: float = 760.0
@export_range(0, 5) var max_bounces: int = 2
@export var lifetime: float = 1.6

var bounce_count: int = 0
var _remaining_lifetime: float = 0.0

func setup(origin: Vector2, direction: Vector2) -> void:
	global_position = origin
	velocity = direction.normalized() * speed
	_remaining_lifetime = lifetime


func _physics_process(delta: float) -> void:
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		expired.emit()
		queue_free()
		return

	var collision := move_and_collide(velocity * delta)
	if collision:
		bounce_count += 1
		var normal := collision.get_normal()
		velocity = velocity.bounce(normal)
		global_position += normal * 0.5
		bounced.emit(global_position, normal, bounce_count)
		if bounce_count >= max_bounces:
			expired.emit()
			queue_free()


func _process(_delta: float) -> void:
	var fade := clampf(_remaining_lifetime / lifetime, 0.0, 1.0)
	modulate.a = fade
