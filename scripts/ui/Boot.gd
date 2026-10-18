extends Node
## Boot：加载设置后进入 Title。

func _ready() -> void:
	# Settings autoload 已在 _ready 里 load
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/title/Title.tscn")
