// Google image generation for the Meshy pipeline ("images --google"): Nano Banana Pro
// draws the concept image from the item's prompt plus already-approved images of the
// same kind as style references, and the white background is cut away so the PNG
// matches what Meshy's own text-to-image returns.
//
// Key: tools/meshy/gemini.local.json ({"key": "..."}, git-ignored), else $env:GEMINI_API_KEY.
import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createCanvas, loadImage } from "@napi-rs/canvas";

const HERE = dirname(fileURLToPath(import.meta.url));
const KEY_FILE = join(HERE, "gemini.local.json");
const MODEL = "gemini-3-pro-image";
const API = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

const STYLE_LEAD = "The attached images are approved assets from the same game. Create a NEW one in exactly " +
	"the same art style: same 3D render look, materials, proportions, lighting, saturation, level of detail, " +
	"camera angle and scale. Do not copy the subjects of the reference images. Subject: ";

export async function geminiKey() {
	if (existsSync(KEY_FILE)) {
		// Notepad and PowerShell may save a byte-order mark first.
		const { key } = JSON.parse((await readFile(KEY_FILE, "utf8")).replace(/^﻿/, ""));
		if (typeof key === "string" && key.trim()) return key.trim();
	}
	return process.env.GEMINI_API_KEY ?? "";
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// Returns the generated image (JPEG or PNG bytes). refs: paths of style reference images.
export async function generateImage(key, prompt, refs = []) {
	const images = await Promise.all(refs.map(async (file) => ({
		inlineData: { mimeType: file.endsWith(".png") ? "image/png" : "image/jpeg", data: (await readFile(file)).toString("base64") },
	})));
	const text = refs.length ? STYLE_LEAD + prompt : prompt;
	for (let attempt = 0; ; attempt++) {
		const response = await fetch(API, {
			method: "POST",
			headers: { "x-goog-api-key": key, "Content-Type": "application/json" },
			body: JSON.stringify({
				contents: [{ parts: [...images, { text }] }],
				generationConfig: { responseModalities: ["IMAGE"], imageConfig: { aspectRatio: "1:1" } },
			}),
		});
		if ((response.status === 429 || response.status >= 500) && attempt < 5) {
			await sleep(3000 * 2 ** attempt);
			continue;
		}
		const body = await response.json().catch(() => ({}));
		if (!response.ok) throw new Error(`gemini -> ${response.status}: ${body.error?.message?.slice(0, 300) ?? ""}`);
		const part = body.candidates?.[0]?.content?.parts?.find((candidate) => candidate.inlineData);
		if (part) return Buffer.from(part.inlineData.data, "base64");
		// A blocked or empty answer is worth one more try before giving up.
		if (attempt >= 1) throw new Error(`gemini returned no image (${body.candidates?.[0]?.finishReason ?? "no candidates"})`);
	}
}

// Near-white pixels reachable from the image border become transparent, with a soft
// edge one step further in. White inside the subject (a belly, a tower) is kept
// because the outline and shading wall it off from the border.
export async function cutWhiteBackground(bytes, { hard = 22, soft = 48 } = {}) {
	const image = await loadImage(bytes);
	const { width, height } = image;
	const canvas = createCanvas(width, height);
	const context = canvas.getContext("2d");
	context.drawImage(image, 0, 0);
	const data = context.getImageData(0, 0, width, height);
	const pixels = data.data;
	const distance = (i) => 255 - Math.min(pixels[i], pixels[i + 1], pixels[i + 2]);
	const seen = new Uint8Array(width * height);
	const stack = [];
	for (let x = 0; x < width; x++) stack.push(x, (height - 1) * width + x);
	for (let y = 0; y < height; y++) stack.push(y * width, y * width + width - 1);
	while (stack.length) {
		const p = stack.pop();
		if (seen[p]) continue;
		seen[p] = 1;
		const d = distance(p * 4);
		if (d >= soft) continue;
		pixels[p * 4 + 3] = d <= hard ? 0 : Math.round(255 * (d - hard) / (soft - hard));
		if (d > hard) continue;
		const x = p % width;
		if (x > 0) stack.push(p - 1);
		if (x < width - 1) stack.push(p + 1);
		if (p >= width) stack.push(p - width);
		if (p < width * (height - 1)) stack.push(p + width);
	}
	context.putImageData(data, 0, 0);
	return canvas.toBuffer("image/png");
}
