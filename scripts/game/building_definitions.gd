extends RefCounted
## Sengoku adaptations of the EU4 building categories. Costs and effects are game balance values.

const DEFINITIONS := {
	"irrigation": {"name":"用水路", "category":"agriculture", "cost":100, "months":12, "effect":"兵糧収入 +10%"},
	"market": {"name":"市場", "category":"commerce", "cost":100, "months":12, "effect":"金銭収入 +10%"},
	"office": {"name":"郡役所", "category":"governance", "cost":80, "months":12, "effect":"治安 +5"},
	"workshop": {"name":"工房", "category":"production", "cost":150, "months":15, "effect":"金銭収入 +15%"},
	"temple": {"name":"寺社", "category":"taxation", "cost":120, "months":12, "effect":"金銭収入 +5%・治安 +2"},
	"farm_estate": {"name":"農園", "category":"agriculture", "cost":180, "months":18, "effect":"兵糧収入 +15%"},
	"barracks": {"name":"兵舎", "category":"army", "cost":140, "months":12, "effect":"徴兵可能な総数 +50%"},
	"fort": {"name":"砦", "category":"defense", "cost":200, "months":18, "effect":"郡の防御 +3"},
}
