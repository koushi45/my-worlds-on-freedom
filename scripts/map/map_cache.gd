extends RefCounted
static func touch(cache: Dictionary, key: Variant) -> Variant:
	var value=cache[key]
	cache.erase(key);cache[key]=value
	return value

static func trim(cache: Dictionary, costs: Dictionary, budget: int) -> int:
	var total:=0
	for n in costs.values():total+=int(n)
	while total>budget and not cache.is_empty():
		var key=cache.keys()[0]
		total-=costs.get(key,0);costs.erase(key);cache.erase(key)
	return total
