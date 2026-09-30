class_name Weight
extends RefCounted
## Кто на ком лежит и сколько весит. Вес — естественное свойство тел (игроков и ящиков),
## а не отдельная способность: стопка давит на то, на чём стоит нижний, висящий на руке
## нагружает того, кто его держит. Замерший в воздухе — якорь: вес на нём обрывается.
##
## Тела с весом состоят в группе GROUP и дают `mass` и `get_support()` — прямую опору.
## Расчёт делается один раз за физический кадр по первому запросу.

const GROUP := "weighted"
## Группа тел, которые везут на себе замершего: ящики, качели, плиты.
const CARRIERS := "carriers"

static var _frame := -1
## Тело -> прямая опора (null — опоры нет).
static var _support := {}
## Опора-конец (не тело с весом) -> Array[Dictionary] {body, mass, contact: Node2D}.
static var _loads := {}


## Все тела с весом, чья цепочка опор заканчивается на node.
## contact — нижнее тело цепочки, которое касается node (по его x считается плечо на качелях).
static func loads_on(node: Node) -> Array:
	_refresh(node.get_tree())
	return _loads.get(node, [])


static func total_on(node: Node) -> float:
	var total := 0.0
	for entry: Dictionary in loads_on(node):
		total += entry.mass
	return total


## Тела, которые опираются прямо на node (стоят на нём или висят на нём).
static func riders_of(node: Node) -> Array:
	_refresh(node.get_tree())
	var result := []
	for body: Node in _support:
		if _support[body] == node:
			result.append(body)
	return result


## Все тела с весом, которые прямо или через других опираются на node.
static func stack_on(node: Node) -> Array:
	var result := []
	var queue := riders_of(node)
	while not queue.is_empty():
		var body: Node = queue.pop_back()
		if body in result:
			continue
		result.append(body)
		queue.append_array(riders_of(body))
	return result


static func _refresh(tree: SceneTree) -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		return
	_frame = frame
	_support.clear()
	_loads.clear()
	var bodies := tree.get_nodes_in_group(GROUP)
	for body: Node in bodies:
		_support[body] = body.get_support()
	for body: Node in bodies:
		if body.mass <= 0.0:
			continue
		var contact := body
		var node: Node = _support[body]
		var visited := {body: true}
		while node != null and _support.has(node) and not visited.has(node):
			visited[node] = true
			contact = node
			node = _support[node]
		if node == null or _support.has(node):
			continue  # опоры нет (якорь в воздухе) или цепочка замкнулась на себя
		if not _loads.has(node):
			_loads[node] = []
		_loads[node].append({"body": body, "mass": body.mass, "contact": contact})


## Опора под телом по пробному сдвигу вниз: для тех, кто не двигается сам (замерший).
static func probe_below(body: PhysicsBody2D, distance := 4.0) -> Node:
	var collision := KinematicCollision2D.new()
	if body.test_move(body.global_transform, Vector2(0, distance), collision, 0.08):
		if collision.get_normal().y < -0.5:
			return collision.get_collider()
	return null


## Опора под телом по столкновениям последнего move_and_slide.
static func floor_below(body: CharacterBody2D) -> Node:
	if not body.is_on_floor():
		return null
	for i in body.get_slide_collision_count():
		var collision := body.get_slide_collision(i)
		if collision.get_normal().y < -0.5:
			return collision.get_collider()
	return null
