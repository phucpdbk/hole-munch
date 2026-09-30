#!/usr/bin/env node
// Landmark pipeline: Meshy text-to-image -> image-to-3d -> GLB in assets/landmarks_src.
// Resumable: finished steps are kept in manifest.json, so re-running only does what is missing.
//
//   $env:MESHY_API_KEY = "msy_..."
//   node tools/meshy/meshy-landmarks.mjs images --only eiffel,taj   # review PNGs first
//   node tools/meshy/meshy-landmarks.mjs models --only eiffel,taj
//   node tools/meshy/meshy-landmarks.mjs all                        # every landmark
//   node tools/meshy/meshy-landmarks.mjs images --only eiffel --redo # regenerate one image
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, "..", "..", "assets", "landmarks_src");
const MANIFEST = join(OUT, "manifest.json");
const API = "https://api.meshy.ai/openapi/v1";
const IMAGE_MODEL = "nano-banana-2";
const TARGET_POLYCOUNT = 8000;
const CONCURRENCY = 4;
const POLL_MS = 5000;
const TASK_TIMEOUT_MS = 15 * 60 * 1000;
const STYLE = "stylized miniature toy diorama, chunky simplified shapes, bright soft colors, " +
	"standing on a small square stone plaza base, whole object fully visible and centered, " +
	"three-quarter view from front-right slightly above, plain white background, no text overlay, game asset";

const KEY = process.env.MESHY_API_KEY;
if (!KEY) {
	console.error("Set MESHY_API_KEY in the environment first.");
	process.exit(1);
}

const args = process.argv.slice(2);
const command = args[0];
const flag = (name) => args.includes(name);
const option = (name) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : undefined; };
if (!["images", "models", "all", "status"].includes(command)) {
	console.error("Usage: meshy-landmarks.mjs images|models|all|status [--only id,id] [--redo]");
	process.exit(1);
}

const prompts = JSON.parse(await readFile(join(HERE, "landmarks.json"), "utf8"));
const only = option("--only")?.split(",").map((id) => id.trim()).filter(Boolean);
const unknown = (only ?? []).filter((id) => !prompts[id]);
if (unknown.length) {
	console.error(`Unknown landmark ids: ${unknown.join(", ")}`);
	process.exit(1);
}
const ids = only ?? Object.keys(prompts);
await mkdir(OUT, { recursive: true });
// Keep Godot from importing the raw GLBs; tools/bake_landmarks.gd reads them directly.
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

async function waitFor(kind, id, label) {
	const started = Date.now();
	let lastProgress = -1;
	while (Date.now() - started < TASK_TIMEOUT_MS) {
		const task = await api("GET", `/${kind}/${id}`);
		if (task.status === "SUCCEEDED") return task;
		if (task.status === "FAILED" || task.status === "CANCELED") {
			throw new Error(`${label}: ${kind} ${task.status} ${task.task_error?.message ?? ""}`);
		}
		if (task.progress !== lastProgress) {
			lastProgress = task.progress;
			console.log(`  ${label}: ${kind} ${task.status} ${task.progress ?? 0}%`);
		}
		await sleep(POLL_MS);
	}
	throw new Error(`${label}: ${kind} timed out`);
}

async function download(url, file) {
	const response = await fetch(url);
	if (!response.ok) throw new Error(`download ${file} -> ${response.status}`);
	await writeFile(file, Buffer.from(await response.arrayBuffer()));
}

async function makeImage(id) {
	const entry = (manifest[id] ??= {});
	if (entry.imageTask && !flag("--redo")) return;
	const prompt = `${prompts[id]}. ${STYLE}`;
	const { result } = await api("POST", "/text-to-image", {
		ai_model: IMAGE_MODEL, prompt, aspect_ratio: "1:1", remove_background: true,
	});
	const task = await waitFor("text-to-image", result, id);
	await download(task.image_urls[0], join(OUT, `${id}.png`));
	Object.assign(entry, { imageTask: result, prompt, modelTask: undefined, glb: undefined });
	entry.credits = (entry.credits ?? 0) + (task.consumed_credits ?? 0);
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
		target_polycount: TARGET_POLYCOUNT,
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
	entry.glb = `${id}.glb`;
	entry.credits = (entry.credits ?? 0) + (task.consumed_credits ?? 0);
	await saveManifest();
	console.log(`✓ model ${id}`);
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
		console.log(`${id.padEnd(16)} image:${entry.imageTask ? "yes" : "-"} glb:${entry.glb ? "yes" : "-"} credits:${entry.credits ?? 0}`);
	}
	process.exit(0);
}
const failures = [];
if (command === "images" || command === "all") failures.push(...await runAll(makeImage));
if (command === "models" || command === "all") failures.push(...await runAll(makeModel));
const spent = ids.reduce((sum, id) => sum + (manifest[id]?.credits ?? 0), 0);
console.log(`Done. Credits recorded for these landmarks: ${spent}.`);
if (failures.length) {
	console.error(`Failed: ${[...new Set(failures)].join(",")} (re-run to retry)`);
	process.exit(1);
}
