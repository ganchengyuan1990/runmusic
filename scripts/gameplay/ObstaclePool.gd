extends Node
class_name ObstaclePool
## 障碍对象池：按 note.t - look_ahead 激活，按 t + miss_window 回收。

@export var obstacle_scene: PackedScene
@export var initial_size: int = 16

var _inactive: Array[Node] = []
var _active: Array[Node] = []


func _ready() -> void:
	if obstacle_scene == null:
		push_warning("ObstaclePool: obstacle_scene not set")
		return
	for i in initial_size:
		var inst := obstacle_scene.instantiate()
		inst.visible = false
		inst.set_process(false)
		add_child(inst)
		_inactive.append(inst)


func acquire() -> Node:
	var node: Node
	if _inactive.is_empty():
		if obstacle_scene == null:
			return null
		node = obstacle_scene.instantiate()
		add_child(node)
	else:
		node = _inactive.pop_back()
	node.visible = true
	node.set_process(true)
	_active.append(node)
	return node


func release(node: Node) -> void:
	if node == null:
		return
	var idx := _active.find(node)
	if idx >= 0:
		_active.remove_at(idx)
	node.visible = false
	node.set_process(false)
	# TODO: 重置 note 绑定 / 位置
	_inactive.append(node)


func release_all() -> void:
	for n in _active.duplicate():
		release(n)


func get_active() -> Array[Node]:
	return _active
