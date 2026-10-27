// Cartoon art for the animated ads (ANIMATED-ADS.md), drawn by Gemini's image
// model (Nano Banana Pro) with the Facebook key art as style reference:
//   node godot/tools/ads/cartoon.mjs sheets [zib quackers ...]
//     character sheets -> godot/test-output/animated/characters/<id>-vN.png
//   node godot/tools/ads/cartoon.mjs keyframes a1-snack-time [s1-fridge ...]
//     9:16 first frames for the shots in shots/<ad>.json, with the cast's latest
//     sheets as references -> godot/test-output/animated/<ad>/<shot>-key-vN.png
// Each run adds a new -vN so earlier takes stay for comparison. Key: as
// tools/meshy/gemini.mjs.
import { readFile, writeFile, mkdir, readdir } from "node:fs/promises";
import { dirname, join, isAbsolute } from "node:path";
import { fileURLToPath } from "node:url";
import { geminiKey } from "../meshy/gemini.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..", "..");
const ART = join(ROOT, "assets", "facebook");
const ANIMATED = join(ROOT, "godot", "test-output", "animated");
const OUT = join(ANIMATED, "characters");
const KEY_ART = "hole-munch-cover-v2-ufo.png";
const MODEL = "gemini-3-pro-image";
const API = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

const STYLE = "Premium stylized 3D cartoon render like a modern animated feature film: glossy rounded toy-like forms, " +
	"soft global illumination, juicy specular highlights, saturated cyan, sunny yellow and violet palette, expressive " +
	"oversized eyes, clean readable silhouettes. Match the art style of the attached Hole Munch key art exactly.";
const SHEET = "Character model sheet on a plain light grey background, 16:9: the same character shown full body " +
	"front view, three-quarter view, side view and back view in a row, plus a row of four face close-ups " +
	"(happy, shocked, angry, sneaky). Identical design, colours and proportions in every view. Even studio lighting, " +
	"no shadows on the background, no text, no labels, no watermark.";

const CHARACTERS = {
	zib: {
		refs: ["hole-munch-cover-v2-ufo.png", "hole-munch-avatar-v6-crown.png"],
		prompt: "ZIB, the small lime-green alien pilot from the attached key art: round head, two thin antennae with " +
			"round ball tips, huge white eyes with small black pupils, wide toothy grin, short stubby body, three-fingered " +
			"hands, no clothes. Include one extra full view of ZIB sitting in his silver flying saucer with cyan " +
			"rim lights and a clear bubble canopy.",
	},
	quackers: {
		refs: ["hole-munch-cover-v2-ufo.png", "hole-munch-avatar-v6-crown.png", "hole-munch-avatar-v4-duck.png"],
		prompt: "KING QUACKERS, the giant fluffy yellow duck from the attached key art: soft fluffy yellow feathers, " +
			"big orange beak, huge white eyes, small golden crown with ball tips, holding a wooden bath brush. " +
			"Include one extra view of him sitting in his white clawfoot bubble bath.",
	},
	bella: {
		refs: ["hole-munch-cover-v2-ufo.png"],
		prompt: "BELLA, a cute cartoon dairy cow in the same style: brown coat with cream patches, a flower crown of " +
			"pink, white and yellow daisies between her small horns, a round yellow cow bell on a collar, big sassy eyes " +
			"with long lashes, pink muzzle, chubby rounded body standing on four legs.",
	},
	pigeon: {
		refs: ["hole-munch-cover-v2-ufo.png"],
		prompt: "SGT. PIGEON, a plump grey city pigeon in the same style: iridescent green-purple neck, orange eyes, " +
			"tiny navy police cap, a silver whistle on a cord round his neck, holding a small clipboard under one wing, " +
			"strict but nervous expression.",
	},
};

// refs: file names in assets/facebook, or absolute paths.
async function draw(key, prompt, refs, aspectRatio) {
	const images = await Promise.all(refs.map(async (file) => ({
		inlineData: { mimeType: "image/png", data: (await readFile(isAbsolute(file) ? file : join(ART, file))).toString("base64") },
	})));
	for (let attempt = 0; ; attempt++) {
		const response = await fetch(API, {
			method: "POST",
			headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
			body: JSON.stringify({
				contents: [{ parts: [...images, { text: prompt }] }],
				generationConfig: { responseModalities: ["IMAGE"], imageConfig: { aspectRatio } },
			}),
		});
		if ((response.status === 429 || response.status >= 500) && attempt < 4) {
			await new Promise((resolve) => setTimeout(resolve, 3000 * 2 ** attempt));
			continue;
		}
		const body = await response.json().catch(() => ({}));
		if (!response.ok) throw new Error(`gemini -> ${response.status}: ${body.error?.message?.slice(0, 300) ?? ""}`);
		const part = body.candidates?.[0]?.content?.parts?.find((candidate) => candidate.inlineData);
		if (part) return Buffer.from(part.inlineData.data, "base64");
		if (attempt >= 1) throw new Error(`no image (${body.candidates?.[0]?.finishReason ?? "no candidates"})`);
	}
}

// Takes in dir named <stem>-vN.png, oldest first.
async function takes(dir, stem) {
	const pattern = new RegExp(`^${stem}-v(\\d+)\\.png$`);
	const names = (await readdir(dir).catch(() => [])).filter((name) => pattern.test(name));
	return names.sort((a, b) => parseInt(a.match(pattern)[1]) - parseInt(b.match(pattern)[1])).map((name) => join(dir, name));
}

async function nextName(dir, stem) {
	return join(dir, `${stem}-v${(await takes(dir, stem)).length + 1}.png`);
}

async function sheets(key, ids) {
	await mkdir(OUT, { recursive: true });
	for (const id of ids.length ? ids : Object.keys(CHARACTERS)) {
		const character = CHARACTERS[id];
		if (!character) throw new Error(`unknown character ${id}`);
		const bytes = await draw(key, `${character.prompt}\n\n${SHEET}\n\n${STYLE}`, character.refs, "16:9");
		const file = await nextName(OUT, id);
		await writeFile(file, bytes);
		console.log(`sheet: ${file}`);
	}
}

const FRAME = "One single cinematic frame from an animated feature film, vertical 9:16 composition, the action " +
	"readable on a phone, main subject in the middle 70% of the frame. No text, no letters, no logos, no captions, " +
	"no split panels, no borders.";

async function keyframes(key, ad, ids) {
	const plan = JSON.parse(await readFile(join(HERE, "shots", `${ad}.json`), "utf8"));
	const dir = join(ANIMATED, ad);
	await mkdir(dir, { recursive: true });
	for (const shot of plan.shots.filter((s) => !ids.length || ids.includes(s.id))) {
		const sheetsUsed = [];
		for (const id of shot.cast) {
			const latest = (await takes(OUT, id)).at(-1);
			if (!latest) throw new Error(`no sheet for ${id}: run "sheets ${id}" first`);
			sheetsUsed.push(latest);
		}
		const lead = sheetsUsed.length ? `The first ${sheetsUsed.length} attached image(s) are character model sheets: ` +
			`draw ${shot.cast.map((c) => c.toUpperCase()).join(" and ")} exactly as designed there. ` : "";
		const prompt = `${lead}The last attached image is the game's key art, for style only.\n\n${shot.keyframe}\n\n${FRAME}\n\n${STYLE}`;
		const file = await nextName(dir, `${shot.id}-key`);
		await writeFile(file, await draw(key, prompt, [...sheetsUsed, KEY_ART], "9:16"));
		console.log(`keyframe: ${file}`);
	}
}

const [command, ...args] = process.argv.slice(2);
const key = await geminiKey();
if (!key) throw new Error("No Gemini key: tools/meshy/gemini.local.json or $env:GEMINI_API_KEY");
if (command === "sheets") await sheets(key, args);
else if (command === "keyframes" && args.length) await keyframes(key, args[0], args.slice(1));
else {
	console.error("usage: cartoon.mjs sheets [ids] | keyframes <ad> [shot ids]");
	process.exit(1);
}
