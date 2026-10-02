#!/usr/bin/env node
// Kept for old notes: same as `node tools/meshy/meshy.mjs landmarks <command> ...`.
process.argv.splice(2, 0, "landmarks");
await import("./meshy.mjs");
