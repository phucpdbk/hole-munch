// Animates the approved keyframes of an animated ad (ANIMATED-ADS.md) with Kling
// 3.0 image-to-video, one task per shot of shots/<ad>.json:
//   node godot/tools/ads/kling.mjs animate a1-snack-time [s1-fridge ...] [--take=2] [--res=720p]
// The first frame is the shot's latest keyframe (<shot>-key-vN.png, or vN with
// --take); the clip lands next to it as <shot>-vN.mp4 and the units charged are
// printed per shot.
//   node godot/tools/ads/kling.mjs sounds a1-snack-time [ids] [--fresh]
// makes the ad's sound effects and music loop (text-to-audio). Key: godot/tools/ads/kling.local.json ({"key": "api-key-kling-..."},
// git-ignored), else $env:KLING_API_KEY.
import { readFile, writeFile, readdir, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ANIMATED = join(HERE, "..", "..", "test-output", "animated");
const API = "https://api-singapore.klingai.com";
const NEGATIVE = "Avoid: text, letters, subtitles, logos, extra limbs, morphing faces, characters changing design, blurry, flicker.";

async function klingKey() {
	const file = join(HERE, "kling.local.json");
	if (existsSync(file)) {
		const { key } = JSON.parse((await readFile(file, "utf8")).replace(/^﻿/, ""));
		if (typeof key === "string" && key.trim()) return key.trim();
	}
	return process.env.KLING_API_KEY ?? "";
}

async function call(key, method, path, body) {
	const response = await fetch(API + path, {
		method,
		headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
		body: body ? JSON.stringify(body) : undefined,
	});
	const json = await response.json().catch(() => ({}));
	if (!response.ok || json.code !== 0) throw new Error(`kling ${method} ${path} -> ${response.status} ${json.code ?? ""}: ${json.message ?? ""}`);
	return json.data;
}

async function versions(dir, pattern) {
	const names = (await readdir(dir).catch(() => [])).filter((name) => pattern.test(name));
	return names.map((name) => ({ name, n: parseInt(name.match(pattern)[1]) })).sort((a, b) => a.n - b.n);
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function animate(key, ad, ids, take, resolution) {
	const plan = JSON.parse(await readFile(join(HERE, "shots", `${ad}.json`), "utf8"));
	const dir = join(ANIMATED, ad);
	const jobs = [];
	for (const shot of plan.shots.filter((s) => !ids.length || ids.includes(s.id))) {
		const frames = await versions(dir, new RegExp(`^${shot.id}-key-v(\\d+)\\.png$`));
		const frame = take ? frames.find((f) => f.n === take) : frames.at(-1);
		if (!frame) throw new Error(`no keyframe for ${shot.id}${take ? ` v${take}` : ""}: run cartoon.mjs keyframes first`);
		const image = (await readFile(join(dir, frame.name))).toString("base64");
		const task = await call(key, "POST", "/image-to-video/kling-3.0", {
			contents: [{ type: "prompt", text: `${shot.motion} ${NEGATIVE}` }, { type: "first_frame", url: image }],
			settings: { resolution, duration: shot.seconds, audio: "off", multi_shot: false },
			options: { watermark_info: { enabled: false } },
		});
		console.log(`${shot.id}: task ${task.id} from ${frame.name}`);
		jobs.push({ shot, task: task.id });
	}
	let units = 0;
	while (jobs.length) {
		await sleep(10000);
		const states = await call(key, "GET", `/tasks?task_ids=${jobs.map((job) => job.task).join(",")}`);
		for (const state of states) {
			const job = jobs.find((j) => j.task === state.id);
			if (!job || !["succeeded", "failed"].includes(state.status)) continue;
			jobs.splice(jobs.indexOf(job), 1);
			if (state.status === "failed") {
				console.log(`${job.shot.id}: FAILED ${state.message ?? ""}`);
				continue;
			}
			const video = state.outputs.find((output) => output.type === "video");
			const taken = await versions(dir, new RegExp(`^${job.shot.id}-v(\\d+)\\.mp4$`));
			const file = join(dir, `${job.shot.id}-v${(taken.at(-1)?.n ?? 0) + 1}.mp4`);
			await writeFile(file, Buffer.from(await (await fetch(video.url)).arrayBuffer()));
			const charged = (state.billing ?? []).reduce((sum, bill) => sum + Number(bill.amount ?? 0), 0);
			units += charged;
			console.log(`${job.shot.id}: ${file} (${video.duration}s, ${charged} units)`);
		}
	}
	console.log(`total charged: ${units} units`);
}

// Sound effects and the music loop ("sounds" of shots/<ad>.json) from Kling
// text-to-audio, as <ad>/audio/<id>.wav; one already there is kept unless fresh.
async function sounds(key, ad, ids, fresh) {
	const plan = JSON.parse(await readFile(join(HERE, "shots", `${ad}.json`), "utf8"));
	const dir = join(ANIMATED, ad, "audio");
	await mkdir(dir, { recursive: true });
	const jobs = [];
	for (const sound of plan.sounds.filter((s) => !ids.length || ids.includes(s.id))) {
		if (existsSync(join(dir, `${sound.id}.wav`)) && !fresh) continue;
		const task = await call(key, "POST", "/v1/audio/text-to-audio", { prompt: sound.prompt, duration: sound.seconds });
		console.log(`${sound.id}: task ${task.task_id}`);
		jobs.push({ sound, task: task.task_id });
	}
	let units = 0;
	while (jobs.length) {
		await sleep(5000);
		for (const job of [...jobs]) {
			const state = await call(key, "GET", `/v1/audio/text-to-audio/${job.task}`);
			if (!["succeed", "failed"].includes(state.task_status)) continue;
			jobs.splice(jobs.indexOf(job), 1);
			if (state.task_status === "failed") {
				console.log(`${job.sound.id}: FAILED ${state.task_status_msg ?? ""}`);
				continue;
			}
			const file = join(dir, `${job.sound.id}.wav`);
			await writeFile(file, Buffer.from(await (await fetch(state.task_result.audios[0].url_wav)).arrayBuffer()));
			units += Number(state.final_unit_deduction ?? 0);
			console.log(`${job.sound.id}: ${file} (${state.final_unit_deduction ?? "?"} units)`);
		}
	}
	console.log(`total charged: ${units} units`);
}

const [command, ad, ...rest] = process.argv.slice(2);
const flag = (name) => rest.find((arg) => arg.startsWith(`--${name}=`))?.split("=")[1];
const ids = rest.filter((arg) => !arg.startsWith("--"));
const key = await klingKey();
if (!key) throw new Error("No Kling key: godot/tools/ads/kling.local.json or $env:KLING_API_KEY");
if (command === "animate" && ad) await animate(key, ad, ids, Number(flag("take") ?? 0), flag("res") ?? "1080p");
else if (command === "sounds" && ad) await sounds(key, ad, ids, rest.includes("--fresh"));
else {
	console.error("usage: kling.mjs animate <ad> [shot ids] [--take=N] [--res=720p|1080p] | sounds <ad> [ids] [--fresh]");
	process.exit(1);
}
