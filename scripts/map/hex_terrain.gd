extends RefCounted
## Travel time, in game days per adjacent tile. The road must connect both tiles.
const PLAIN := 0
const MOUNTAIN := 1
const RIVER := 2
const HIGH_MOUNTAIN := 3
const NO_LAND := 4

static func name_for(kind: int) -> String:
	match kind:
		MOUNTAIN: return "山地"
		RIVER: return "川"
		HIGH_MOUNTAIN: return "高山地"
		NO_LAND: return "陸地なし"
		_: return "平地"

static func days_for(kind: int, connected_road: bool) -> float:
	match kind:
		HIGH_MOUNTAIN, NO_LAND: return INF
		RIVER: return 1.5 if connected_road else 5.0
		MOUNTAIN: return 1.5 if connected_road else 2.5
		_: return 1.0 if connected_road else 1.5
