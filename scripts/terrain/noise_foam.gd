class_name NoiseFoam
extends StaticBody2D

func _ready() -> void:
	add_to_group(&"sound_absorber")


func apply_horizontal_mirror(is_mirrored: bool) -> void:
	if is_mirrored:
		position.x = -position.x
