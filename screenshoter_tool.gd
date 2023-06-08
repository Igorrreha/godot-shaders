@tool
extends EditorScript


func _run() -> void:
	var viewport_path = get_script().get_meta("target_viewport")
	var viewport = get_scene().get_node(viewport_path)
	var file_path = "res://screenshots/%s-%s.png" % [viewport.name, randi()]
	viewport.get_texture().get_image().save_png(file_path)
	print("Screenshot saved at %s!" % file_path)
