// Voice lines for an animated ad (the "lines" of shots/<ad>.json), spoken by
// Gemini TTS in each character's voice ("voices"):
//   node godot/tools/ads/voice.mjs a1-snack-time [line ids] [--fresh]
// Writes godot/test-output/animated/<ad>/audio/<line>.wav; a line already there is
// kept unless --fresh. Key: as tools/meshy/gemini.mjs. Needs ffmpeg (PATH or winget).
import { readFile, writeFile, mkdir, rm } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { geminiKey } from "../meshy/gemini.mjs";
import { ffmpeg } from "./media.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const ANIMATED = join(HERE, "..", "..", "test-output", "animated");
const MODEL = "gemini-2.5-flash-preview-tts";
const API = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

async function speak(key, text, voice) {
	for (let attempt = 0; ; attempt++) {
		const response = await fetch(API, {
			method: "POST",
			headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
			body: JSON.stringify({
				contents: [{ parts: [{ text }] }],
				generationConfig: { responseModalities: ["AUDIO"], speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } } },
			}),
		});
		if ((response.status === 429 || response.status >= 500) && attempt < 4) {
			await new Promise((resolve) => setTimeout(resolve, 3000 * 2 ** attempt));
			continue;
		}
		const body = await response.json().catch(() => ({}));
		if (!response.ok) throw new Error(`gemini tts -> ${response.status}: ${body.error?.message?.slice(0, 300) ?? ""}`);
		const part = body.candidates?.[0]?.content?.parts?.find((candidate) => candidate.inlineData);
		if (part) return { pcm: Buffer.from(part.inlineData.data, "base64"), mime: part.inlineData.mimeType };
		if (attempt >= 1) throw new Error(`no audio (${body.candidates?.[0]?.finishReason ?? "no candidates"})`);
	}
}

const [ad, ...rest] = process.argv.slice(2);
if (!ad) {
	console.error("usage: voice.mjs <ad> [line ids] [--fresh]");
	process.exit(1);
}
const fresh = rest.includes("--fresh");
const ids = rest.filter((arg) => !arg.startsWith("--"));
const plan = JSON.parse(await readFile(join(HERE, "shots", `${ad}.json`), "utf8"));
const dir = join(ANIMATED, ad, "audio");
await mkdir(dir, { recursive: true });
const key = await geminiKey();
if (!key) throw new Error("No Gemini key: tools/meshy/gemini.local.json or $env:GEMINI_API_KEY");
for (const line of plan.lines.filter((l) => !ids.length || ids.includes(l.id))) {
	const file = join(dir, `${line.id}.wav`);
	if (existsSync(file) && !fresh) continue;
	const cast = plan.voices[line.who];
	const { pcm, mime } = await speak(key, `${cast.style}, ${line.mood}: ${line.text}`, cast.voice);
	const rate = mime.match(/rate=(\d+)/)?.[1] ?? "24000";
	const raw = join(dir, `${line.id}.pcm`);
	await writeFile(raw, pcm);
	// Trim the silence the model leaves around the line.
	const run = spawnSync(ffmpeg(), ["-y", "-loglevel", "error", "-f", "s16le", "-ar", rate, "-ac", "1", "-i", raw,
		"-af", "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse",
		"-ar", "48000", "-ac", "2", file], { stdio: "inherit" });
	await rm(raw);
	if (run.status !== 0) throw new Error(`ffmpeg failed on ${line.id}`);
	console.log(`line: ${file}`);
}
