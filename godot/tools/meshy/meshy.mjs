#!/usr/bin/env node
// Meshy asset pipeline: text-to-image -> image-to-3d -> GLB, for three kinds:
//   landmarks -> assets/landmarks_src/<id>.glb  (bake: tools/bake_landmarks.gd)
//   mascots   -> assets/mascots_src/<id>.glb plus <id>@<clip>.glb animations after
//                "rig" (Meshy auto-rigging + animation library; bake: tools/bake_mascots.gd)
//   crafts    -> assets/crafts_src/<index>.glb  (bake: tools/bake_crafts.gd)
// Prompts live in tools/meshy/<kind>.json. Resumable: finished steps are kept in
// each output folder's manifest.json, so re-running only does what is missing.
//
//   $env:MESHY_API_KEY = "msy_..."
//   node tools/meshy/meshy.mjs mascots images --only onepillar,namsan   # review PNGs first
//   node tools/meshy/meshy.mjs mascots models --only onepillar
//   node tools/meshy/meshy.mjs mascots rig --only onepillar             # skeleton + clips
//   node tools/meshy/meshy.mjs crafts all
//   node tools/meshy/meshy.mjs landmarks status
//   node tools/meshy/meshy.mjs mascots images --only fuji --redo        # regenerate one image
//   node tools/meshy/meshy.mjs mascots library                          # list animation ids
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ASSETS = join(HERE, "..", "..", "assets");
const API = "https://api.meshy.ai/openapi/v1";
const IMAGE_MODEL = "nano-banana-2";
const CONCURRENCY = 4;
const POLL_MS = 5000;
const TASK_TIMEOUT_MS = 15 * 60 * 1000;

const KINDS = {
	landmarks: {
		out: "landmarks_src", polycount: 8000,
		style: "stylized miniature toy diorama, chunky simplified shapes, bright soft colors, " +
			"standing on a small square stone plaza base, whole object fully visible and centered, " +
			"three-quarter view from front-right slightly above, plain white background, no text overlay, game asset",
	},
	// Auto-rigging needs a two-legged character with clear limbs, facing the camera.
	mascots: {
		out: "mascots_src", polycount: 10000, rig: true,
		style: "chibi toy mascot character, standing upright on two legs in a T-pose with arms spread out to the sides " +
			"and legs slightly apart, clearly separated arms and legs, chunky simplified shapes, bright soft colors, " +
			"full body visible and centered, front view facing the camera, plain white background, no text overlay, game asset",
	},
	crafts: {
		out: "crafts_src", polycount: 5000,
		style: "stylized toy spaceship, chunky simplified shapes, bright soft colors, whole object fully visible and centered, " +
			"three-quarter view from slightly above, floating with no base or stand, plain white background, no text overlay, game asset",
	},
};
// Animation library clips for each guardian state: the first library entry whose
// name matches the pattern. walk and run come with the rig itself. Override with
// --actions idle=12,attack=4 after checking "library".
const CLIP_PATTERNS = { idle: /idle/i, attack: /attack|punch|slash/i, hit: /hit|damage|hurt/i, leap: /jump/i };
const RIG_HEIGHT_METERS = 1.2;

const KEY = process.env.MESHY_API_KEY;
const args = process.argv.slice(2);
const [kindName, command] = args;
const kind = KINDS[kindName];
const flag = (name) => args.includes(name);
const option = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
const commands = ["images", "models", "all", "status", ...(kind?.rig ? ["rig", "library"] : [])];
if (!kind || !commands.includes(command)) {
	console.error("Usage: meshy.mjs landmarks|mascots|crafts images|models|all|status [--only id,id] [--redo]");
	console.error("       meshy.mjs mascots rig|library [--only id,id] [--redo] [--actions idle=N,attack=N,hit=N,leap=N]");
	process.exit(1);
}
if (!KEY) {
	console.error("Set MESHY_API_KEY in the environment first.");
	process.exit(1);
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

async function api(method, path, body) {
	for (let attempt = 0; ; attempt++) {
		const response = await fetch(API + path, {
			method,
			headers: { Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" },
			body: body ? JSON.stringify(body) : undefined,
		});
		if (response.status === 429 && attempt < 6) {
			await sleep(2000 * 2 ** attempt);
			continue;
		}
		const text = await response.text();
		if (!response.ok) throw new Error(`${method} ${path} -> ${response.status}: ${text.slice(0, 300)}`);
		return JSON.parse(text);
	}
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function waitFor(endpoint, id, label) {
	const started = Date.now();
	let lastProgress = -1;
	while (Date.now() - started < TASK_TIMEOUT_MS) {
		const task = await api("GET", `/${endpoint}/${id}`);
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

async function makeImage(id) {
	const entry = (manifest[id] ??= {});
	if (entry.imageTask && !flag("--redo")) return;
	const prompt = `${prompts[id]}. ${kind.style}`;
	const { result } = await api("POST", "/text-to-image", {
		ai_model: IMAGE_MODEL, prompt, aspect_ratio: "1:1", remove_background: true,
	});
	const task = await waitFor("text-to-image", result, id);
	await download(task.image_urls[0], join(OUT, `${id}.png`));
	Object.assign(entry, { imageTask: result, prompt, modelTask: undefined, glb: undefined, rigTask: undefined, clips: undefined });
	credit(entry, task);
	await saveManifest();
	console.log(`✓ image ${id}`);
}

async function makeModel(id) {
	const entry = manifest[id];
	if (!entry?.imageTask) throw new Error(`${id}: run "images" first`);
	if (entry.glb && !flag("--redo")) return;
	const { result } = await api("POST", "/image-to-3d", {
		input_task_id: entry.imageTask,
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
	const task = await waitFor("image-to-3d", result, id);
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
	const response = await api("GET", "/animations/library");
	const list = Array.isArray(response) ? response : response.result ?? response.data ?? response.animations ?? [];
	library = list.map((entry) => ({ id: entry.action_id ?? entry.id, name: String(entry.name ?? entry.action_name ?? "") }));
	return library;
}

async function clipActions() {
	const chosen = {};
	for (const pair of (option("--actions") ?? "").split(",").filter(Boolean)) {
		const [clip, id] = pair.split("=");
		chosen[clip.trim()] = Number(id);
	}
	const entries = await animationLibrary();
	for (const [clip, pattern] of Object.entries(CLIP_PATTERNS)) {
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
	if (!entry.rigTask || flag("--redo")) {
		const { result } = await api("POST", "/rigging", { input_task_id: entry.modelTask, height_meters: RIG_HEIGHT_METERS });
		entry.rigTask = result;
		await saveManifest();
	}
	const rig = await waitFor("rigging", entry.rigTask, id);
	credit(entry, rig);
	const results = rig.result ?? {};
	await download(results.rigged_character_glb_url, join(OUT, `${id}.glb`));
	const clips = [];
	const basic = results.basic_animations ?? {};
	if (basic.walking_glb_url) { await download(basic.walking_glb_url, join(OUT, `${id}@walk.glb`)); clips.push("walk"); }
	if (basic.running_glb_url) { await download(basic.running_glb_url, join(OUT, `${id}@run.glb`)); clips.push("run"); }
	for (const [clip, actionId] of Object.entries(await clipActions())) {
		const { result } = await api("POST", "/animations", { rig_task_id: entry.rigTask, action_id: actionId });
		const task = await waitFor("animations", result, `${id}@${clip}`);
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

if (command === "status") {
	for (const id of ids) {
		const entry = manifest[id] ?? {};
		const rigged = kind.rig ? ` clips:${entry.clips?.join("+") ?? "-"}` : "";
		console.log(`${id.padEnd(16)} image:${entry.imageTask ? "yes" : "-"} glb:${entry.glb ? "yes" : "-"}${rigged} credits:${entry.credits ?? 0}`);
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
