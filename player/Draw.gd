extends ImmediateGeometry


var point: = Vector3.ZERO
onready var body: = $"../Body"

func _process(delta):
	
	clear()
	begin(Mesh.PRIMITIVE_LINE_STRIP)
	add_vertex(Vector3.ZERO)
	add_vertex(point)
	end()
