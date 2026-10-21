extends RefCounted

# Dresses a festival city (campaign.gd HOLIDAYS) for its holiday: every street
# tree, bench and opening cone becomes the theme's tree, stand or snack
# (festive_models.gd) at the same size, so food totals and routes stay those of
# the plain city. Variants alternate so a street mixes two or three looks.
# Variant counts keep the city within its render-batch budget (campaign_smoke).
const SWAPS := {"tree":["fest_tree", 2], "bench":["fest_stand", 2], "cone":["fest_snack", 1]}

static func decorate(g) -> void:
	var theme: String = g.level.get("theme", "")
	if theme == "": return
	g.models.festive_theme = theme
	var count := 0
	for item in g.items:
		if not SWAPS.has(item.kind): continue
		var swap: Array = SWAPS[item.kind]
		item.kind = swap[0]
		item.variant = count % int(swap[1])
		item.batch = item.kind + str(item.variant)
		count += 1
