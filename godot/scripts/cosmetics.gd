extends RefCounted

# Coin prices and journey rewards for the hole's looks, ported from the 2D shop
# (src/cosmetics.js, src/progression.js). Indices match Campaign.SKINS, EFFECTS
# and TRAILS because saves store them; SKIN_ORDER is only the shop's display order.
const SLOTS := ["skins", "effects", "trails"]
# A price of REWARD means the item cannot be bought, only earned on the journey.
const REWARD := -1
const PRICES := {
	"skins": [0, 300, 800, 1000, 1200, 1500, 5000, 3000, 2000, REWARD, REWARD, REWARD, 500],
	"effects": [0, 200, 300, 400, 600, 800, 1000],
	"trails": [0, 250, 400, 600, 800, 1200],
}
# Cheapest first, journey rewards last, as in the 2D shop.
const SKIN_ORDER := [0, 1, 12, 2, 3, 4, 5, 8, 7, 6, 11, 9, 10]
# [slot, index, track, need]: "stars" counts medals, "landmarks" cities whose
# landmark was swallowed. An earned reward is owned even if it also has a price.
const REWARDS := [
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

static func reward_only(slot: String, index: int) -> bool:
	return price(slot, index) == REWARD

static func reward_for(slot: String, index: int) -> Array:
	for reward in REWARDS:
		if reward[0] == slot and reward[1] == index: return reward
	return []

static func display_order(slot: String) -> Array:
	if slot == "skins": return SKIN_ORDER
	return range(count(slot))
