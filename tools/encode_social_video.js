#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";

function argValue(name, fallback = "") {
  const prefix = `${name}=`;
  const arg = process.argv.slice(2).find((value) => value.startsWith(prefix));
  return arg ? arg.slice(prefix.length) : fallback;
}

const manifestPath = resolve(argValue("--manifest"));
const outputPath = resolve(argValue("--output", "social_highlight.mp4"));

if (!manifestPath || !existsSync(manifestPath)) {
  console.error("ENCODE_SOCIAL_VIDEO: missing --manifest=<path>");
  process.exit(1);
}

const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
const out = manifest.output ?? {};
const fps = Math.max(1, Number(out.fps ?? 30));
const width = Math.max(320, Number(out.width ?? 1080));
const height = Math.max(320, Number(out.height ?? 1920));
const framePattern = join(dirname(manifestPath), "frame_%06d.png");

const ffmpegArgs = [
  "-y",
  "-framerate",
  String(fps),
  "-i",
  framePattern,
  "-vf",
  `scale=${width}:${height}:force_original_aspect_ratio=decrease,pad=${width}:${height}:(ow-iw)/2:(oh-ih)/2,format=yuv420p`,
  "-c:v",
  "libx264",
  "-profile:v",
  "high",
  "-preset",
  "medium",
  "-movflags",
  "+faststart",
  "-crf",
  "20",
  outputPath
];

const result = spawnSync("ffmpeg", ffmpegArgs, { stdio: "pipe", encoding: "utf8" });
if (result.status !== 0) {
  console.error("ENCODE_SOCIAL_VIDEO: ffmpeg failed");
  if (result.stderr) {
    console.error(result.stderr);
  }
  process.exit(result.status ?? 1);
}

console.log(
  JSON.stringify(
    {
      ok: true,
      output: outputPath,
      fps,
      width,
      height,
      cta: manifest.cta ?? {}
    },
    null,
    2
  )
);
