extends Node2D
## Populate Japanese glyph/outline caches during startup, outside the viewport.
signal finished
var labels: Array = []
var cursor := 0
var complete := false

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var start := Time.get_ticks_usec()
	while cursor<labels.size():
		var entry: Dictionary=labels[cursor]
		draw_string_outline(font,Vector2(-10000,-10000),entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,entry.size,entry.outline,Color.BLACK)
		draw_string(font,Vector2(-10000,-10000),entry.text,HORIZONTAL_ALIGNMENT_LEFT,-1,entry.size,Color.WHITE)
		cursor+=1
		if Time.get_ticks_usec()-start>3000:break
	if cursor==labels.size():complete=true

func _process(_delta: float) -> void:
	if complete:
		set_process(false)
		finished.emit()
		queue_free()
	else:queue_redraw()
