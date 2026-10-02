extends Node2D
## Original polyline draw commands survive camera translation and rotation.
var rings: Array = []
var width := 1.0
var color := Color.WHITE

func _draw() -> void:
    for ring in rings:
        if ring.size()>=2: draw_polyline(ring,color,width,true)
