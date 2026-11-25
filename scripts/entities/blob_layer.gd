class_name BlobLayer
extends MultiMeshInstance3D
## All soft contact shadows under units (low quality setting) drawn as one MultiMesh: one draw
## call for every unit instead of one each. Units register while they need a blob.

static var _layers := {}  # top 3D node instance id -> BlobLayer

var members: Array[CharacterModel] = []

static func join(m: CharacterModel) -> void:
	var top: Node = m
	while top.get_parent() is Node3D:
		top = top.get_parent()
	var key := top.get_instance_id()
	var layer: BlobLayer = _layers.get(key)
	if layer == null or not is_instance_valid(layer):
		layer = BlobLayer.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = CharacterModel._blob_quad()
		mm.instance_count = 64
		mm.visible_instance_count = 0
		layer.multimesh = mm
		layer.material_override = CharacterModel._blob_material()
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.top_level = true
		# units join while their parent is entering the tree, when the top node cannot take children yet
		top.add_child.call_deferred(layer)
		_layers[key] = layer
	if not layer.members.has(m):
		layer.members.append(m)

static func leave(m: CharacterModel) -> void:
	for k in _layers:
		var layer: BlobLayer = _layers[k]
		if is_instance_valid(layer):
			layer.members.erase(m)

func _ready() -> void:
	tree_exiting.connect(func(): _layers.erase(_layers.find_key(self)))

func _process(_d: float) -> void:
	var mm := multimesh
	var n := 0
	var lie := Basis(Vector3.RIGHT, -PI / 2)
	var aabb := AABB()
	for m in members:
		if not is_instance_valid(m) or not m.ground_blob or not m.is_visible_in_tree():
			continue
		if n >= mm.instance_count:
			var keep := mm.visible_instance_count
			mm.instance_count *= 2
			mm.visible_instance_count = keep
		var s := m._blob_size * m.global_basis.get_scale().x
		var p := m.to_global(Vector3(0, m.blob_y, 0))
		mm.set_instance_transform(n, Transform3D(lie.scaled(Vector3(s, s, s)), p))
		aabb = AABB(p, Vector3.ZERO) if n == 0 else aabb.expand(p)
		n += 1
	mm.visible_instance_count = n
	custom_aabb = aabb.grow(3.0)
