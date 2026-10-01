#!/bin/bash
set -euo pipefail

# Exports the "Web" preset and publishes it to the gh-pages branch, which GitHub
# Pages serves at https://phucpdbk.github.io/hole-munch/. The previous HTML5 game
# from the repo root is kept under /classic/, and privacy.html stays at the root
# because store listings link to it. Usage: bash godot/tools/deploy-web.sh [--no-push]
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_root="$(cd "$project_root/.." && pwd)"
godot_bin="${GODOT_BIN:-Godot_v4.7.1-stable_win64_console.exe}"
export_dir="$project_root/builds/web"
site_dir="$project_root/builds/gh-pages"
branch=gh-pages

rm -rf "$export_dir"
mkdir -p "$export_dir"
"$godot_bin" --headless --path "$project_root" --export-release "Web" "$export_dir/index.html"
[[ -f "$export_dir/index.wasm" && -f "$export_dir/index.pck" ]] || { echo 'Web export failed.' >&2; exit 1; }

git -C "$repo_root" worktree remove --force "$site_dir" 2>/dev/null || true
rm -rf "$site_dir"
if git -C "$repo_root" ls-remote --exit-code --heads origin "$branch" >/dev/null; then
  git -C "$repo_root" fetch -q origin "$branch"
  git -C "$repo_root" worktree add -q -B "$branch" "$site_dir" "origin/$branch"
else
  git -C "$repo_root" worktree add -q --orphan -b "$branch" "$site_dir"
fi

find "$site_dir" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$export_dir"/. "$site_dir"/
mkdir -p "$site_dir/classic"
cp -r "$repo_root/index.html" "$repo_root/style.css" "$repo_root/src" "$repo_root/assets" "$site_dir/classic"/
cp "$repo_root/privacy.html" "$site_dir"/
touch "$site_dir/.nojekyll"

git -C "$site_dir" add -A
if git -C "$site_dir" diff --cached --quiet; then
  echo 'Site unchanged.'
else
  git -C "$site_dir" commit -q -m "deploy: web build from $(git -C "$repo_root" rev-parse --short HEAD)"
fi
if [[ "${1:-}" != --no-push ]]; then
  git -C "$site_dir" push -q origin "$branch"
  echo "Published $branch: https://phucpdbk.github.io/hole-munch/"
fi
git -C "$repo_root" worktree remove --force "$site_dir"
