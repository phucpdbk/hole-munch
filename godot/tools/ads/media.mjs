// Shared helpers for the animated-ad tools: where ffmpeg lives, and media length.
import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

let found = "";

// ffmpeg from PATH, else the winget Gyan.FFmpeg install.
export function ffmpeg() {
	if (found) return found;
	if (spawnSync("ffmpeg", ["-version"]).status === 0) return (found = "ffmpeg");
	const packages = join(process.env.LOCALAPPDATA ?? "", "Microsoft", "WinGet", "Packages");
	for (const pkg of existsSync(packages) ? readdirSync(packages).filter((name) => name.startsWith("Gyan.FFmpeg")) : []) {
		for (const build of readdirSync(join(packages, pkg))) {
			const exe = join(packages, pkg, build, "bin", "ffmpeg.exe");
			if (existsSync(exe)) return (found = exe);
		}
	}
	throw new Error("ffmpeg not found: winget install Gyan.FFmpeg");
}

export function ffprobe() {
	const exe = ffmpeg();
	return exe === "ffmpeg" ? "ffprobe" : exe.replace(/ffmpeg\.exe$/, "ffprobe.exe");
}

export function duration(file) {
	const run = spawnSync(ffprobe(), ["-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file], { encoding: "utf8" });
	return Number(run.stdout.trim());
}
