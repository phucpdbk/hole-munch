extends RefCounted

# Coin prices for the saucer and the hole's looks, ported from the 2D shop
# (src/cosmetics.js). Every look is bought with coins; index 0 of each slot is
# free. Indices match Fleet.NAMES, Campaign.SKINS, EFFECTS and TRAILS because
# saves store them; SKIN_ORDER is only the shop's display order.
const SLOTS := ["crafts", "skins", "effects", "trails"]
const PRICES := {
	# Plain saucers are cheap; the creature and crystal ships are the prizes.
	"crafts": [0, 400, 700, 1000, 1200, 1500, 1800, 2400, 3500, 4500, 6000, 8000, 12000],
	"skins": [0, 300, 800, 1000, 1200, 1500, 5000, 3000, 2000, 3500, 7000, 2500, 500],
	"effects": [0, 200, 300, 400, 600, 800, 1000],
	"trails": [0, 250, 400, 600, 800, 1200],
}
# Cheapest first, as in the 2D shop.
const SKIN_ORDER := [0, 1, 12, 2, 3, 4, 5, 8, 11, 7, 9, 6, 10]
# Before version 9 these looks were earned on the journey instead of bought:
# [slot, index, track, need] with "stars" = medals and "landmarks" = cities taken.
# Old saves that had earned one keep it (Campaign.restore_owned).
const LEGACY_REWARDS := [
	["effects", 1, "stars", 6],
	["skins", 11, "stars", 18],
	["trails", 5, "stars", 36],
	["skins", 9, "landmarks", 6],
	["skins", 10, "landmarks", 24],
]
# Saves before version 6 had four effects and four trails; map them onto the
# 2D-style lists (crystals -> pixels, embers -> stars, rainbow trail moved).
const OLD_EFFECTS := [0, 1, 5, 3]
const OLD_TRAILS := [0, 1, 2, 5]

static func count(slot: String) -> int:
	return PRICES[slot].size()

static func price(slot: String, index: int) -> int:
	return int(PRICES[slot][index])

static func display_order(slot: String) -> Array:
	if slot == "skins": return SKIN_ORDER
	return range(count(slot))
