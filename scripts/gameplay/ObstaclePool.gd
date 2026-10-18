extends Node
class_name ObstaclePool
## 障碍对象池。活跃实例挂到 ObstacleRoot（Node2D），回收后隐藏并停用。

@export var obstacle_scene: PackedScene
@export var obstacle_root_path: NodePath
@export var initial_size: int = 16

var _inactive: Array[Node] = []
var _active: Array[Node] = []
var _obstacle_root: Node2D


func _ready() -> void:
	if obstacle_root_path:
		_obstacle_root = get_node_or_null(obstacle_root_path) as Node2D
	if obstacle_scene == null:
		push_warning("ObstaclePool: obstacle_scene not set")
		return
	for _i in initial_size:
		var inst := obstacle_scene.instantiate()
		_deactivate(inst)
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
	_attach_to_world(node)
	node.visible = true
	node.set_process(true)
	_active.append(node)
	return node


func release(node: Node) -> void:
	if node == null or _inactive.has(node):
		return
	var idx := _active.find(node)
	if idx >= 0:
		_active.remove_at(idx)
	_deactivate(node)
	if node.has_method("clear_note"):
		node.call("clear_note")
	_inactive.append(node)


func release_all() -> void:
	for n in _active.duplicate():
		release(n)


func get_active() -> Array[Node]:
	return _active


func _attach_to_world(node: Node) -> void:
	if _obstacle_root == null:
		return
	if node.get_parent() != _obstacle_root:
		node.reparent(_obstacle_root)


func _deactivate(node: Node) -> void:
	node.visible = false
	node.set_process(false)
