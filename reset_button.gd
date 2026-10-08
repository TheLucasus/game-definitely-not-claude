extends Node3D

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		# Press 'R' to completely regenerate the scene
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()
