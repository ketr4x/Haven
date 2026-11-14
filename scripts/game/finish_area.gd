class_name FinishArea
extends Area2D

signal player_finished(player: RezonansPlayer)

func _on_body_entered(body: Node2D) -> void:
	if body is RezonansPlayer:
		player_finished.emit(body)
