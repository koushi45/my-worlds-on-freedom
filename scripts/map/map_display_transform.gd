class_name MapDisplayTransform
extends RefCounted

const DEFAULT_TILT := 0.72
const DEFAULT_SHEAR := 0.18


static func top_down_to_oblique(point: Vector2, tilt: float = DEFAULT_TILT, shear: float = DEFAULT_SHEAR) -> Vector2:
	return Vector2(point.x + shear * point.y, point.y * tilt)


static func oblique_to_top_down(point: Vector2, tilt: float = DEFAULT_TILT, shear: float = DEFAULT_SHEAR) -> Vector2:
	var source_y := point.y / tilt
	return Vector2(point.x - shear * source_y, source_y)
