extends RefCounted

# Street look per landmark city: which shophouse style lines the blocks, its wall
# and shop-sign colours, the roof colour, how often blocks become high-rise
# districts (0 = village, 1 = skyline) and the two tower styles (mid, high).
# Shophouse and tower builders live in street_models.gd.
const DEFAULT := "eiffel"
const PROFILES = {
	# Asia
	"onepillar": {"style":"tube", "walls":["f2c94c","f4a6a0","9fd3b5"], "signs":["d93a2f","2f6fd9","e8a33d"], "roof":"8e8f93", "towers":0.25, "tower":["concrete","concrete"]},
	"namsan": {"style":"asia_city", "walls":["d9d4cc","c9b8a6","e6e1d8"], "signs":["e0413f","3a7bd5","f2b134"], "roof":"7d858c", "towers":0.6, "tower":["concrete","glass"]},
	"khuevan": {"style":"tube", "walls":["e9d9a0","e3a98a","b8d4e0"], "signs":["c8322b","e8c23d","2e8b57"], "roof":"8e8f93", "towers":0.2, "tower":["concrete","concrete"]},
	"watarun": {"style":"asia_city", "walls":["f0e2c2","e8c7a0","cfd8c8"], "signs":["d4a017","c0392b","1f7a8c"], "roof":"a86b4a", "towers":0.45, "tower":["concrete","glass"]},
	"taj": {"style":"mughal", "walls":["e8c9a0","f0dccb","d99a7a"], "signs":["e0508f","f2a93b","2aa198"], "roof":"c9a27a", "towers":0.1, "tower":["concrete","concrete"]},
	"pearl": {"style":"asia_city", "walls":["d6d2cb","bfc3c7","e3d7c3"], "signs":["e53935","f9a825","8e24aa"], "roof":"6f7780", "towers":0.9, "tower":["glass","pagoda"]},
	"fuji": {"style":"machiya", "walls":["6b4a35","7a5a44","d8cdb8"], "signs":["2c4a7a","b03a2e","e0c080"], "roof":"4a4f57", "towers":0.1, "tower":["concrete","concrete"]},
	"tokyotower": {"style":"asia_city", "walls":["e2e0dc","c8ccd0","d9cbb8"], "signs":["e8383d","2b7de9","f4c20d"], "roof":"6f7780", "towers":0.8, "tower":["glass","glass"]},
	# Europe
	"eiffel": {"style":"haussmann", "walls":["efe4cf","e6d8bf","f2ead9"], "signs":["b22a2a","1f5c3a","1d3f6e"], "roof":"6d7a86", "towers":0.12, "tower":["stone","stone"]},
	"brandenburg": {"style":"altbau", "walls":["e8d9b0","c9d6cf","e6c3a8"], "signs":["b22a2a","1d3f6e","2e6b3a"], "roof":"a65a42", "towers":0.4, "tower":["concrete","glass"]},
	"bigben": {"style":"brick", "walls":["a4553d","8c4a3a","c9b79c"], "signs":["1f5c3a","b22a2a","1d3f6e"], "roof":"4f5660", "towers":0.4, "tower":["stone","glass"]},
	"alcala": {"style":"mediterranean", "walls":["e8c9a0","f0dcc0","d9a47a"], "signs":["2e6b3a","b22a2a","e0a030"], "roof":"b8603f", "towers":0.3, "tower":["stone","glass"]},
	"pisa": {"style":"mediterranean", "walls":["e6b87a","f0d9a8","d98c5f"], "signs":["2e6b3a","8e2a2a","1f4f7a"], "roof":"b8603f", "towers":0.0, "tower":["stone","stone"]},
	"royalpalace": {"style":"canal", "walls":["6e3b2a","3f3a36","8a5a3c"], "signs":["1d3f6e","2e6b3a","b22a2a"], "roof":"3f4650", "towers":0.1, "tower":["stone","stone"]},
	"colosseum": {"style":"mediterranean", "walls":["d9905f","e8b77a","c97a52"], "signs":["2e6b3a","8e2a2a","e0a030"], "roof":"b0583a", "towers":0.05, "tower":["stone","stone"]},
	"stbasils": {"style":"russian", "walls":["f0d58a","b8d8c8","e8b8a8"], "signs":["b22a2a","1d3f6e","2e6b3a"], "roof":"5f8f6a", "towers":0.5, "tower":["concrete","deco"]},
	# Africa
	"pyramid": {"style":"arab", "walls":["e0c08f","d8b27a","ead3aa"], "signs":["2a7ab0","c0392b","e0a030"], "roof":"c9a87a", "towers":0.1, "tower":["adobe","adobe"]},
	"cairotower": {"style":"arab", "walls":["d8c3a0","c9a87a","e6d3b0"], "signs":["c0392b","2a7ab0","2e8b57"], "roof":"b89a70", "towers":0.5, "tower":["adobe","glass"]},
	"sphinx": {"style":"arab", "walls":["e6c898","d4a870","f0dcb4"], "signs":["e0a030","2a7ab0","8e44ad"], "roof":"c9a87a", "towers":0.1, "tower":["adobe","adobe"]},
	"kicc": {"style":"african", "walls":["f2b134","5fb3a8","e76f51"], "signs":["c0392b","2a7ab0","2e8b57"], "roof":"8d8f93", "towers":0.5, "tower":["concrete","glass"]},
	"djenne": {"style":"sahel", "walls":["c98f55","b87c48","d6a06a"], "signs":["2a7ab0","e0a030","c0392b"], "roof":"a8733f", "towers":0.0, "tower":["adobe","adobe"]},
	"nationaltheatre": {"style":"african", "walls":["f4d35e","ee964b","7fc8a9"], "signs":["2e8b57","c0392b","1d3f6e"], "roof":"9a6a4a", "towers":0.6, "tower":["concrete","glass"]},
	"baobab": {"style":"african", "walls":["e9c46a","f4a261","a8dadc"], "signs":["c0392b","2e8b57","2a7ab0"], "roof":"a0522d", "towers":0.0, "tower":["concrete","concrete"]},
	"tablemountain": {"style":"capedutch", "walls":["f06292","64b5f6","ffd54f"], "signs":["1d3f6e","2e8b57","c0392b"], "roof":"eef0ea", "towers":0.4, "tower":["hotel","glass"]},
	# North America
	"liberty": {"style":"brownstone", "walls":["8b4a3a","6e4b3a","a0624a"], "signs":["2e6b3a","b22a2a","1d3f6e"], "roof":"4f5660", "towers":0.85, "tower":["glass","deco"]},
	"willis": {"style":"brownstone", "walls":["9c5a45","b8a48a","7a4535"], "signs":["b22a2a","1d3f6e","e0a030"], "roof":"4f5660", "towers":0.9, "tower":["glass","glass"]},
	"empire": {"style":"brownstone", "walls":["a0624a","8b4a3a","c9b79c"], "signs":["1d3f6e","b22a2a","2e6b3a"], "roof":"4f5660", "towers":0.9, "tower":["deco","deco"]},
	"cntower": {"style":"brownstone", "walls":["a4553d","c9b79c","8a8f96"], "signs":["c0392b","2a7ab0","2e8b57"], "roof":"4f5660", "towers":0.7, "tower":["glass","glass"]},
	"needle": {"style":"stucco", "walls":["8a9aa8","b5a48a","6f7f6a"], "signs":["2e8b57","c0392b","2a7ab0"], "roof":"5d6770", "towers":0.6, "tower":["glass","glass"]},
	"hollywood": {"style":"stucco", "walls":["f2e6d0","f4c7a1","b8e0d2"], "signs":["e63946","2a9d8f","f4a261"], "roof":"d8cfc0", "towers":0.4, "tower":["hotel","glass"]},
	"chichen": {"style":"colonial", "walls":["e76f51","f4a261","2a9d8f"], "signs":["1d3f6e","e9c46a","c0392b"], "roof":"b8603f", "towers":0.05, "tower":["concrete","concrete"]},
	"capitol": {"style":"brownstone", "walls":["c9b79c","a4553d","e6dccb"], "signs":["1d3f6e","b22a2a","2e6b3a"], "roof":"4f5660", "towers":0.25, "tower":["stone","stone"]},
	# South America
	"christ": {"style":"colonial", "walls":["f4d35e","4ecdc4","ff6b6b"], "signs":["1d3f6e","c0392b","2e8b57"], "roof":"b8603f", "towers":0.5, "tower":["hotel","glass"]},
	"masp": {"style":"stucco", "walls":["c8c4bc","d9cbb0","a9b0b5"], "signs":["e53935","f9a825","1d3f6e"], "roof":"7d858c", "towers":0.95, "tower":["concrete","glass"]},
	"machu": {"style":"colonial", "walls":["f2ede4","e8dcc8","d9c9a8"], "signs":["1d3f6e","2e6b3a","b22a2a"], "roof":"a8553a", "towers":0.0, "tower":["concrete","concrete"]},
	"limacathedral": {"style":"colonial", "walls":["f4d35e","e9c46a","9fc5e8"], "signs":["c0392b","1d3f6e","2e6b3a"], "roof":"b8603f", "towers":0.3, "tower":["concrete","glass"]},
	"obelisco": {"style":"haussmann", "walls":["e6dccb","d8cfc0","c9b79c"], "signs":["1d6fb0","b22a2a","2e6b3a"], "roof":"5d6770", "towers":0.6, "tower":["stone","glass"]},
	"monserrate": {"style":"brick", "walls":["a0522d","8b4513","b5654a"], "signs":["f2c94c","1d3f6e","c0392b"], "roof":"8a4a32", "towers":0.5, "tower":["concrete","glass"]},
	"sugarloaf": {"style":"colonial", "walls":["ff8c69","7ec8e3","f7dc6f"], "signs":["2e8b57","c0392b","1d3f6e"], "roof":"b8603f", "towers":0.4, "tower":["hotel","hotel"]},
	"costanera": {"style":"stucco", "walls":["e6dccb","f0e2c2","c9d6df"], "signs":["c0392b","2a7ab0","f2b134"], "roof":"8a8f96", "towers":0.8, "tower":["glass","glass"]},
	# Oceania
	"sydney": {"style":"victorian", "walls":["e8d8b8","b5654a","f0e6d2"], "signs":["1d3f6e","2e6b3a","b22a2a"], "roof":"7d858c", "towers":0.7, "tower":["glass","glass"]},
	"flinders": {"style":"victorian", "walls":["c9a27a","e6d3b0","8b5a3c"], "signs":["2e6b3a","b22a2a","e0a030"], "roof":"7d858c", "towers":0.7, "tower":["glass","glass"]},
	"uluru": {"style":"island", "walls":["c1502e","e0a070","f0e0c0"], "signs":["2a7ab0","2e8b57","e0a030"], "roof":"9aa0a6", "towers":0.0, "tower":["hotel","hotel"]},
	"belltower": {"style":"victorian", "walls":["f0e0c0","d9a47a","e6dccb"], "signs":["1d3f6e","c0392b","2e8b57"], "roof":"7d858c", "towers":0.5, "tower":["glass","glass"]},
	"skytower": {"style":"victorian", "walls":["f0f0e8","cfe2dc","f4d8a8"], "signs":["1d3f6e","2e8b57","c0392b"], "roof":"b8603f", "towers":0.5, "tower":["glass","glass"]},
	"fijitemple": {"style":"island", "walls":["4ecdc4","f7b267","f25f5c"], "signs":["1d3f6e","e9c46a","2e8b57"], "roof":"9aa0a6", "towers":0.05, "tower":["hotel","hotel"]},
	"moai": {"style":"island", "walls":["f2e6d0","9fd3c7","f4a261"], "signs":["2a7ab0","c0392b","2e8b57"], "roof":"8a7a6a", "towers":0.0, "tower":["hotel","hotel"]},
	"parliament": {"style":"stucco", "walls":["efe6d6","d9d2c3","c9d6df"], "signs":["2e6b3a","1d3f6e","c0392b"], "roof":"8a8f96", "towers":0.3, "tower":["concrete","glass"]},
}

static func profile(landmark: String) -> Dictionary:
	return PROFILES.get(landmark, PROFILES[DEFAULT])
