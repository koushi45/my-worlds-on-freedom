extends Node2D
var point := Vector2.ZERO
func _draw() -> void:
    draw_circle(point,0.8,Color(1,0,1))
