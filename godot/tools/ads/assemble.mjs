// Cuts an animated ad from the "edit" list of shots/<ad>.json: Kling shots
// (latest <shot>-vN.mp4), gameplay clips recorded by make-ad-videos.ps1 and the end
// card, each with its caption, voice lines and sound effects, then the music loop
// under the whole thing. Output: godot/test-output/animated/<ad>/<ad>-vN.mp4
// (1080x1920, 30 fps, H.264 + AAC).
//   node godot/tools/ads/assemble.mjs a1-snack-time
import { readFile, writeFile, readdir, mkdir, rm, copyFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { ffmpeg, duration } from "./media.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const GODOT = join(HERE, "..", "..");
const ANIMATED = join(GODOT, "test-output", "animated");
const FPS = 30;
const VIDEO = `scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1,fps=${FPS}`;
const AUDIO = "aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo";
const MUSIC_VOLUME = 0.3;

function run(args, cwd) {
	const result = spawnSync(ffmpeg(), ["-y", "-loglevel", "error", ...args], { cwd, stdio: "inherit" });
	if (result.status !== 0) throw new Error(`ffmpeg failed: ${args.join(" ").slice(0, 200)}`);
}

async function latest(dir, stem, ext) {
	const pattern = new RegExp(`^${stem}-v(\\d+)\\.${ext}$`);
	const names = (await readdir(dir).catch(() => [])).filter((name) => pattern.test(name));
	names.sort((a, b) => parseInt(a.match(pattern)[1]) - parseInt(b.match(pattern)[1]));
	return names.length ? join(dir, names.at(-1)) : "";
}

// Big outlined caption, by default in the top third (captionTop: a share of the
// height, lower for clips that keep the HUD), fading in over 0.2 s. Baloo 2 is a
// variable font drawtext can only draw at its regular weight, so a thick navy
// pass goes under the white text, which a thin white border fattens.
function caption(index, top = 0.13) {
	const text = `fontfile=Baloo2.ttf:textfile=cap-${index}.txt:fontsize=108:x=(w-tw)/2:y=h*${top}:alpha='min(1,t/0.2)'`;
	return `drawtext=${text}:fontcolor=0x172939:borderw=16:bordercolor=0x172939:shadowcolor=0x172939@0.6:shadowx=0:shadowy=10,` +
		`drawtext=${text}:fontcolor=white:borderw=3:bordercolor=white`;
}

// One edit entry -> work/seg-N.mp4 with picture, caption and its own sound.
async function segment(ad, entry, index, work) {
	const out = join(work, `seg-${index}.mp4`);
	const inputs = [];
	let picture;
	let base;
	let length;
	if (entry.card) {
		// The card clip opens on the bare city for a few frames before its wash.
		inputs.push("-ss", "0.3", "-i", join(GODOT, entry.card));
		picture = `[0:v]${VIDEO}[v]`;
		base = `[0:a]${AUDIO}[base]`;
		length = duration(join(GODOT, entry.card)) - 0.3;
	} else if (entry.game) {
		const speed = entry.speed ?? 1;
		inputs.push("-ss", String(entry.from), "-to", String(entry.to), "-i", join(GODOT, entry.game));
		picture = `[0:v]setpts=PTS/${speed},${VIDEO}[v]`;
		base = `[0:a]atempo=${speed},${AUDIO}[base]`;
		length = (entry.to - entry.from) / speed;
	} else {
		const clip = await latest(join(ANIMATED, ad), entry.shot, "mp4");
		if (!clip) throw new Error(`no clip for ${entry.shot}: run kling.mjs animate first`);
		inputs.push("-ss", String(entry.from), "-to", String(entry.to), "-i", clip);
		inputs.push("-f", "lavfi", "-t", String(entry.to - entry.from), "-i", "anullsrc=r=48000:cl=stereo");
		picture = `[0:v]${VIDEO}[v]`;
		base = `[1:a]${AUDIO}[base]`;
		length = entry.to - entry.from;
	}
	const chains = [picture.replace("[v]", entry.caption ? `,${caption(index, entry.captionTop)}[v]` : "[v]"), base];
	const mixed = ["[base]"];
	for (const [id, at] of entry.audio ?? []) {
		const file = join(ANIMATED, ad, "audio", `${id}.wav`);
		if (!existsSync(file)) throw new Error(`missing audio ${id}: run voice.mjs / kling.mjs sounds first`);
		const n = inputs.filter((arg) => arg === "-i").length;
		inputs.push("-i", file);
		const ms = Math.round(at * 1000);
		chains.push(`[${n}:a]${AUDIO},adelay=${ms}|${ms}[a${n}]`);
		mixed.push(`[a${n}]`);
	}
	chains.push(`${mixed.join("")}amix=inputs=${mixed.length}:duration=first:normalize=0[a]`);
	if (entry.caption) await writeFile(join(work, `cap-${index}.txt`), entry.caption);
	run([...inputs, "-filter_complex", chains.join(";"), "-map", "[v]", "-map", "[a]", "-t", length.toFixed(3),
		"-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", out], work);
	return out;
}

const ad = process.argv[2];
if (!ad) {
	console.error("usage: assemble.mjs <ad>");
	process.exit(1);
}
const plan = JSON.parse(await readFile(join(HERE, "shots", `${ad}.json`), "utf8"));
const dir = join(ANIMATED, ad);
const work = join(dir, "work");
await mkdir(work, { recursive: true });
await copyFile(join(GODOT, "assets", "fonts", "Baloo2.ttf"), join(work, "Baloo2.ttf"));
const parts = [];
for (const [index, entry] of plan.edit.entries()) parts.push(await segment(ad, entry, index, work));
const out = (await latest(dir, ad, "mp4")).replace(/-v(\d+)\.mp4$/, (_, n) => `-v${Number(n) + 1}.mp4`) || join(dir, `${ad}-v1.mp4`);
// Joined by the concat filter, not the copy demuxer: the segments' timestamps do
// not line up exactly, and the demuxer drops the start of the ad when they don't.
const total = parts.reduce((sum, part) => sum + duration(part), 0);
const inputs = parts.flatMap((part) => ["-i", part]);
const chains = [`${parts.map((_, i) => `[${i}:v][${i}:a]`).join("")}concat=n=${parts.length}:v=1:a=1[v][speech]`];
const music = join(dir, "audio", "music.wav");
if (existsSync(music)) {
	inputs.push("-stream_loop", "-1", "-i", music);
	chains.push(`[${parts.length}:a]${AUDIO},volume=${MUSIC_VOLUME},atrim=0:${total.toFixed(2)},afade=t=out:st=${(total - 1).toFixed(2)}:d=1[m]`);
	chains.push("[speech][m]amix=inputs=2:duration=first:normalize=0[mix]");
} else chains.push("[speech]anull[mix]");
// Loudness of a typical social video ad.
chains.push("[mix]loudnorm=I=-14:TP=-1.5:LRA=11,aresample=48000[a]");
run([...inputs, "-filter_complex", chains.join(";"), "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "medium",
	"-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", out], work);
if (!process.env.KEEP_WORK) await rm(work, { recursive: true });
console.log(`ad: ${out} (${total.toFixed(1)} s)`);
