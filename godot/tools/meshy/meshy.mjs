#!/usr/bin/env node
// Meshy asset pipeline: text-to-image -> image-to-3d -> GLB, for three kinds:
//   landmarks -> assets/landmarks_src/<id>.glb  (bake: tools/bake_landmarks.gd)
//   mascots   -> assets/mascots_src/<id>.glb plus <id>@<clip>.glb animations after
//                "rig" (Meshy auto-rigging + animation library; bake: tools/bake_mascots.gd)
//   crafts    -> assets/crafts_src/<index>.glb  (bake: tools/bake_crafts.gd)
//   pickups   -> assets/pickups_src/<kind>.glb  (power-ups that drop on the map; bake: tools/bake_pickups.gd)
//   soldiers  -> assets/soldiers_src/<id>.glb plus <id>@<clip>.glb after "rig" (army foot units;
//                bake: tools/bake_mascots.gd soldiers)
// Prompts live in tools/meshy/<kind>.json. Resumable: finished steps are kept in
// each output folder's manifest.json, so re-running only does what is missing.
//
// Keys: tools/meshy/keys.local.json ({"acc1": "msy_...", "acc2": "msy_..."}, git-ignored;
// see keys.example.json), else $env:MESHY_API_KEY. Each run reads every account's
// balance; a new item starts on the first account with credits for its whole chain
// (image -> model -> rig) and stays pinned to it, because later steps reuse that
// account's task ids. An account that runs dry before an item starts is skipped.
//   node tools/meshy/meshy.mjs crafts balance                           # credits per account
//
//   $env:MESHY_API_KEY = "msy_..."
//   node tools/meshy/meshy.mjs mascots images --only onepillar,namsan   # review PNGs first
//   node tools/meshy/meshy.mjs mascots models --only onepillar
//   node tools/meshy/meshy.mjs mascots rig --only onepillar             # skeleton + clips
//   node tools/meshy/meshy.mjs crafts all
//   node tools/meshy/meshy.mjs landmarks status
//   node tools/meshy/meshy.mjs mascots images --only fuji --redo        # regenerate one image
//   node tools/meshy/meshy.mjs mascots library                          # list animation ids
//
// "images --google" draws the image with Google's Nano Banana Pro instead (see gemini.mjs),
// passing the kind's approved items (refs below, or --refs id,id) as style references.
// It costs no Meshy credits; "models" then sends the PNG itself to image-to-3d.
//   node tools/meshy/meshy.mjs landmarks images --google --only namsan
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { geminiKey, generateImage, cutWhiteBackground } from "./gemini.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ASSETS = join(HERE, "..", "..", "assets");
const API = "https://api.meshy.ai/openapi/v1";
const IMAGE_MODEL = "nano-banana-2";
const CONCURRENCY = 4;
const POLL_MS = 5000;
const TASK_TIMEOUT_MS = 15 * 60 * 1000;

const KINDS = {
	landmarks: {
		out: "landmarks_src", polycount: 8000, refs: ["eiffel", "taj", "sydney"],
		style: "stylized miniature toy diorama, chunky simplified shapes, bright soft colors, " +
			"standing on a small square stone plaza base, whole object fully visible and centered, " +
			"three-quarter view from front-right slightly above, plain white background, no text overlay, game asset",
	},
	// Auto-rigging needs a two-legged character with clear limbs, facing the camera.
	// The game draws fire, water and lightning itself (mascot_attacks.gd); an effect
	// in the image gets baked into the mesh and sticks to the mouth or hands forever.
	mascots: {
		out: "mascots_src", polycount: 10000, rig: true, refs: ["onepillar", "eiffel", "sydney"],
		// The approved guardian clips. Name matching picked "BeHit FlyUp" for hit, which
		// throws the guardian flat on the ground every time the hole bites it.
		actions: { idle: 0, attack: 125, hit: 178, leap: 86 },
		style: "chibi toy mascot character, standing upright on two legs in a T-pose with arms spread out to the sides " +
			"and legs slightly apart, clearly separated arms and legs, mouth closed, empty open hands, " +
			"no props, no weapons, no water, fire, smoke, sparks or other effects, chunky simplified shapes, bright soft colors, " +
			"full body visible and centered, front view facing the camera, plain white background, no text overlay, game asset",
	},
	// Army foot units, rigged like the mascots but low-poly (up to two dozen on
	// screen). No weapon in the image: the game attaches its own gun to the hand.
	// Clips are fixed library ids (see "library"): idle and alert stances, three
	// shooting candidates and a panic wave for when the hole closes in.
	soldiers: {
		out: "soldiers_src", polycount: 3000, rig: true, refs: ["vn_soldier", "vn_police"],
		actions: { idle: 0, alert: 2, shoot: 98, quickdraw: 232, aim: 585, raise: 334, panic: 291 },
		style: "chibi toy soldier figure, standing upright on two legs in a T-pose with arms spread out to the sides " +
			"and legs slightly apart, clearly separated arms and legs, empty open hands, no weapons, no props, no backpack, " +
			"chunky simplified shapes, big head, bright soft colors, full body visible and centered, front view facing the camera, " +
			"plain white background, no text overlay, game asset",
	},
	// Power-ups dropping on the map (mechanics.gd PICKUPS): small, read at a glance.
	pickups: {
		out: "pickups_src", polycount: 3000, refs: ["time", "magnet", "speed"],
		style: "stylized toy game power-up icon, chunky simplified shapes, bright saturated colors, glossy, " +
			"whole object fully visible and centered, three-quarter view from slightly above, floating with no base or stand, " +
			"plain white background, no text, no letters, no numbers, game asset",
	},
	crafts: {
		out: "crafts_src", polycount: 5000, refs: ["0", "1", "2"],
		style: "stylized toy spaceship, chunky simplified shapes, bright soft colors, whole object fully visible and centered, " +
			"three-quarter view from slightly above, floating with no base or stand, plain white background, no text overlay, game asset",
	},
};
// Animation library clips for each guardian state: the first library entry whose
// name matches the pattern. walk and run come with the rig itself. Override with
// --actions idle=12,attack=4 after checking "library".
const CLIP_PATTERNS = { idle: /idle/i, attack: /attack|punch|slash/i, hit: /hit|damage|hurt/i, leap: /jump/i };
const RIG_HEIGHT_METERS = 1.2;

// Estimated credits per step, from past runs (the API only reports some of them);
// used to pick an account with enough left before an item starts.
const COSTS = { image: 6, model: 36, rig: 5, clip: 3 };
const KEYS_FILE = process.env.MESHY_KEYS_FILE ?? join(HERE, "keys.local.json");

const args = process.argv.slice(2);
const [kindName, command] = args;
const kind = KINDS[kindName];
const flag = (name) => args.includes(name);
const option = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
const commands = ["images", "models", "all", "status", "balance", ...(kind?.rig ? ["rig", "library"] : [])];
if (!kind || !commands.includes(command)) {
	console.error("Usage: meshy.mjs landmarks|mascots|crafts|soldiers|pickups images|models|all|status|balance [--only id,id] [--redo]");
	console.error("       meshy.mjs <kind> images --google [--refs id,id] [--only id,id] [--redo]");
	console.error("       meshy.mjs mascots rig|library [--only id,id] [--redo] [--actions idle=N,attack=N,hit=N,leap=N]");
	process.exit(1);
}
const accounts = await loadAccounts();
if (!accounts.length) {
	console.error(`Add keys to ${KEYS_FILE} (see keys.example.json) or set MESHY_API_KEY first.`);
	process.exit(1);
}

// [{label, key, available}] in file order; the key itself is never printed or saved.
async function loadAccounts() {
	if (existsSync(KEYS_FILE)) {
		// Notepad and PowerShell may save a byte-order mark first.
		const keys = JSON.parse((await readFile(KEYS_FILE, "utf8")).replace(/^﻿/, ""));
		return Object.entries(keys)
			.filter(([, key]) => typeof key === "string" && key.trim())
			.map(([label, key]) => ({ label, key: key.trim(), available: 0 }));
	}
	const key = process.env.MESHY_API_KEY;
	return key ? [{ label: "default", key, available: 0 }] : [];
}

const OUT = join(ASSETS, kind.out);
const MANIFEST = join(OUT, "manifest.json");
const prompts = JSON.parse(await readFile(join(HERE, `${kindName}.json`), "utf8"));
const only = option("--only")?.split(",").map((id) => id.trim()).filter(Boolean);
const unknown = (only ?? []).filter((id) => !prompts[id]);
if (unknown.length) {
	console.error(`Unknown ${kindName} ids: ${unknown.join(", ")}`);
	process.exit(1);
}
const ids = only ?? Object.keys(prompts);
await mkdir(OUT, { recursive: true });
// Keep Godot from importing the raw GLBs; the bake tools read them directly.
if (!existsSync(join(OUT, ".gdignore"))) await writeFile(join(OUT, ".gdignore"), "");
const manifest = existsSync(MANIFEST) ? JSON.parse(await readFile(MANIFEST, "utf8")) : {};
const saveManifest = () => writeFile(MANIFEST, JSON.stringify(manifest, null, 2));

// 402 means the account is out of credits: it is marked empty and the error says so.
async function api(account, method, path, body) {
	for (let attempt = 0; ; attempt++) {
		const response = await fetch(API + path, {
			method,
			headers: { Authorization: `Bearer ${account.key}`, "Content-Type": "application/json" },
			body: body ? JSON.stringify(body) : undefined,
		});
		if (response.status === 429 && attempt < 6) {
			await sleep(2000 * 2 ** attempt);
			continue;
		}
		const text = await response.text();
		if (!response.ok) {
			const error = new Error(`[${account.label}] ${method} ${path} -> ${response.status}: ${text.slice(0, 300)}`);
			if (response.status === 402) {
				account.available = 0;
				error.outOfCredits = true;
			}
			throw error;
		}
		return JSON.parse(text);
	}
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function refreshBalances() {
	for (const account of accounts) {
		try {
			account.available = Number((await api(account, "GET", "/balance")).balance) || 0;
		} catch (error) {
			account.available = 0;
			console.error(`  ${account.label}: balance unavailable (${error.message.split(": ").pop().slice(0, 80)})`);
		}
	}
}

const balances = () => accounts.map((account) => `${account.label}=${account.available}`).join(" ");
const clipNames = () => Object.keys(kind.actions ?? CLIP_PATTERNS);
const rigCost = () => COSTS.rig + COSTS.clip * clipNames().length;
const chainCost = (withImage = true) => (withImage ? COSTS.image : 0) + COSTS.model + (kind.rig ? rigCost() : 0);
// Credits held back this run for items that started a chain on their account.
const reserved = {};

// Items made before accounts were tracked belong to the first key (the original one).
function pinnedAccount(id, entry) {
	const label = entry.account ?? accounts[0].label;
	const account = accounts.find((candidate) => candidate.label === label);
	if (!account) throw new Error(`${id}: started on account "${label}", which is not in keys.local.json`);
	return account;
}

// A new chain takes the first account with credits for all of it and reserves them.
function startChain(id, skip = [], withImage = true) {
	const need = chainCost(withImage);
	const account = accounts.find((candidate) => !skip.includes(candidate) && candidate.available >= need);
	if (!account) throw new Error(`${id}: no account has ${need} credits left (${balances()})`);
	account.available -= need;
	reserved[id] = need;
	return account;
}

// A later step stays on the item's account, paid from its reservation or its balance.
function continueChain(id, entry, cost) {
	const account = pinnedAccount(id, entry);
	const held = Math.min(reserved[id] ?? 0, cost);
	reserved[id] = (reserved[id] ?? 0) - held;
	if (account.available < cost - held) {
		throw new Error(`${id}: account "${account.label}" has ${account.available} credits, needs ${cost - held}; top it up or --redo the item`);
	}
	account.available -= cost - held;
	return account;
}

async function waitFor(account, endpoint, id, label) {
	const started = Date.now();
	let lastProgress = -1;
	while (Date.now() - started < TASK_TIMEOUT_MS) {
		const task = await api(account, "GET", `/${endpoint}/${id}`);
		if (task.status === "SUCCEEDED") return task;
		if (task.status === "FAILED" || task.status === "CANCELED") {
			throw new Error(`${label}: ${endpoint} ${task.status} ${task.task_error?.message ?? ""}`);
		}
		if (task.progress !== lastProgress) {
			lastProgress = task.progress;
			console.log(`  ${label}: ${endpoint} ${task.status} ${task.progress ?? 0}%`);
		}
		await sleep(POLL_MS);
	}
	throw new Error(`${label}: ${endpoint} timed out`);
}

async function download(url, file) {
	const response = await fetch(url);
	if (!response.ok) throw new Error(`download ${file} -> ${response.status}`);
	await writeFile(file, Buffer.from(await response.arrayBuffer()));
}

const credit = (entry, task) => { entry.credits = (entry.credits ?? 0) + (task.consumed_credits ?? 0); };

const hasImage = (entry) => Boolean(entry?.imageTask || entry?.imageSource === "google");

// Approved items of this kind (with an image on disk) that steer Google's style.
function styleRefs(id) {
	const chosen = option("--refs")?.split(",").map((ref) => ref.trim()).filter(Boolean) ?? kind.refs ?? [];
	return chosen.filter((ref) => ref !== id && existsSync(join(OUT, `${ref}.png`))).map((ref) => join(OUT, `${ref}.png`));
}

let googleKey;
async function makeGoogleImage(id) {
	const entry = (manifest[id] ??= {});
	const prompt = `${prompts[id]}. ${kind.style}`;
	googleKey ??= await geminiKey();
	if (!googleKey) throw new Error("add a key to tools/meshy/gemini.local.json or set GEMINI_API_KEY");
	const refs = styleRefs(id);
	const bytes = await generateImage(googleKey, prompt, refs);
	await writeFile(join(OUT, `${id}.png`), await cutWhiteBackground(bytes));
	// No Meshy credits spent yet: the account is picked when the model starts.
	Object.assign(entry, { imageSource: "google", account: undefined, imageTask: undefined, prompt,
		modelTask: undefined, glb: undefined, rigTask: undefined, clips: undefined });
	await saveManifest();
	console.log(`✓ image ${id} (google, ${refs.length} refs)`);
}

async function makeImage(id) {
	const entry = (manifest[id] ??= {});
	if (hasImage(entry) && !flag("--redo")) return;
	if (flag("--google")) return makeGoogleImage(id);
	const prompt = `${prompts[id]}. ${kind.style}`;
	// The image starts the chain: an account that turns out empty hands it to the next.
	const tried = [];
	let account;
	let result;
	while (!result) {
		account = startChain(id, tried);
		try {
			({ result } = await api(account, "POST", "/text-to-image", {
				ai_model: IMAGE_MODEL, prompt, aspect_ratio: "1:1", remove_background: true,
			}));
		} catch (error) {
			if (!error.outOfCredits) throw error;
			console.error(`  ${id}: account "${account.label}" is out of credits, trying the next one`);
			tried.push(account);
		}
	}
	Object.assign(entry, { account: account.label, imageTask: result, imageSource: undefined, prompt, modelTask: undefined, glb: undefined, rigTask: undefined, clips: undefined });
	await saveManifest();
	const task = await waitFor(account, "text-to-image", result, id);
	await download(task.image_urls[0], join(OUT, `${id}.png`));
	credit(entry, task);
	await saveManifest();
	console.log(`✓ image ${id}`);
}

async function makeModel(id) {
	const entry = manifest[id];
	if (!hasImage(entry)) throw new Error(`${id}: run "images" first`);
	if (entry.glb && !flag("--redo")) return;
	// A Google image has no Meshy task: its chain starts here and the PNG goes up as a data URI.
	const google = entry.imageSource === "google";
	const account = google && !entry.account ? startChain(id, [], false) : continueChain(id, entry, COSTS.model);
	if (google) entry.account = account.label;
	const input = google
		? { image_url: `data:image/png;base64,${(await readFile(join(OUT, `${id}.png`))).toString("base64")}` }
		: { input_task_id: entry.imageTask };
	const { result } = await api(account, "POST", "/image-to-3d", {
		...input,
		ai_model: "latest",
		should_remesh: true,
		topology: "triangle",
		target_polycount: kind.polycount,
		should_texture: true,
		enable_pbr: false,
		texture_prompt: prompts[id].slice(0, 800),
		target_formats: ["glb"],
	});
	entry.modelTask = result;
	await saveManifest();
	const task = await waitFor(account, "image-to-3d", result, id);
	await download(task.model_urls.glb, join(OUT, `${id}.glb`));
	if (task.thumbnail_url) await download(task.thumbnail_url, join(OUT, `${id}_preview.png`));
	Object.assign(entry, { glb: `${id}.glb`, rigTask: undefined, clips: undefined });
	credit(entry, task);
	await saveManifest();
	console.log(`✓ model ${id}`);
}

let library;
async function animationLibrary() {
	if (library) return library;
	const response = await api(accounts[0], "GET", "/animations/library");
	const list = Array.isArray(response) ? response : response.result ?? response.data ?? response.animations ?? [];
	library = list.map((entry) => ({ id: entry.action_id ?? entry.id, name: String(entry.name ?? entry.action_name ?? "") }));
	return library;
}

async function clipActions() {
	const chosen = { ...(kind.actions ?? {}) };
	for (const pair of (option("--actions") ?? "").split(",").filter(Boolean)) {
		const [clip, id] = pair.split("=");
		chosen[clip.trim()] = Number(id);
	}
	const entries = await animationLibrary();
	for (const [clip, pattern] of Object.entries(kind.actions ? {} : CLIP_PATTERNS)) {
		if (chosen[clip] !== undefined) continue;
		const match = entries.find((entry) => pattern.test(entry.name));
		if (match) chosen[clip] = match.id;
	}
	return chosen;
}

// The character's skeleton (with walk/run), then one GLB per library clip.
// A model that cannot be rigged keeps its static GLB: the game animates it procedurally.
async function makeRig(id) {
	const entry = manifest[id];
	if (!entry?.modelTask || !entry.glb) throw new Error(`${id}: run "models" first`);
	if (entry.clips && !flag("--redo")) return;
	const account = continueChain(id, entry, rigCost());
	if (!entry.rigTask || flag("--redo")) {
		const { result } = await api(account, "POST", "/rigging", { input_task_id: entry.modelTask, height_meters: RIG_HEIGHT_METERS });
		entry.rigTask = result;
		await saveManifest();
	}
	const rig = await waitFor(account, "rigging", entry.rigTask, id);
	credit(entry, rig);
	const results = rig.result ?? {};
	await download(results.rigged_character_glb_url, join(OUT, `${id}.glb`));
	const clips = [];
	const basic = results.basic_animations ?? {};
	if (basic.walking_glb_url) { await download(basic.walking_glb_url, join(OUT, `${id}@walk.glb`)); clips.push("walk"); }
	if (basic.running_glb_url) { await download(basic.running_glb_url, join(OUT, `${id}@run.glb`)); clips.push("run"); }
	for (const [clip, actionId] of Object.entries(await clipActions())) {
		const { result } = await api(account, "POST", "/animations", { rig_task_id: entry.rigTask, action_id: actionId });
		const task = await waitFor(account, "animations", result, `${id}@${clip}`);
		credit(entry, task);
		const url = task.result?.animation_glb_url ?? task.animation_glb_url;
		if (!url) { console.error(`  ${id}@${clip}: no GLB in the result`); continue; }
		await download(url, join(OUT, `${id}@${clip}.glb`));
		clips.push(clip);
	}
	entry.clips = clips;
	await saveManifest();
	console.log(`✓ rig ${id} (${clips.join(", ")})`);
}

async function runAll(step) {
	const queue = [...ids];
	const failures = [];
	await Promise.all(Array.from({ length: CONCURRENCY }, async () => {
		while (queue.length) {
			const id = queue.shift();
			try { await step(id); } catch (error) { failures.push(id); console.error(`✗ ${error.message}`); }
		}
	}));
	return failures;
}

await refreshBalances();
console.log(`Credits: ${balances()} (a new ${kindName} item needs about ${chainCost()})`);
if (command === "balance") process.exit(0);
if (command === "status") {
	for (const id of ids) {
		const entry = manifest[id] ?? {};
		const rigged = kind.rig ? ` clips:${entry.clips?.join("+") ?? "-"}` : "";
		const label = entry.imageTask ? entry.account ?? accounts[0].label : entry.account;
		const account = label ? ` account:${label}` : "";
		const image = entry.imageSource === "google" ? "google" : entry.imageTask ? "yes" : "-";
		console.log(`${id.padEnd(16)} image:${image} glb:${entry.glb ? "yes" : "-"}${rigged} credits:${entry.credits ?? 0}${account}`);
	}
	process.exit(0);
}
if (command === "library") {
	for (const entry of await animationLibrary()) console.log(`${String(entry.id).padStart(5)}  ${entry.name}`);
	console.log("Chosen:", await clipActions());
	process.exit(0);
}
const failures = [];
if (command === "images" || command === "all") failures.push(...await runAll(makeImage));
if (command === "models" || command === "all") failures.push(...await runAll(makeModel));
if (kind.rig && (command === "rig" || command === "all")) failures.push(...await runAll(makeRig));
const spent = ids.reduce((sum, id) => sum + (manifest[id]?.credits ?? 0), 0);
console.log(`Done. Credits recorded for these ${kindName}: ${spent}.`);
if (failures.length) {
	console.error(`Failed: ${[...new Set(failures)].join(",")} (re-run to retry)`);
	process.exit(1);
}
