#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
root="$PWD"
site="${1:-all}"
case "$site" in all|homepage|blog|uses|computer) ;; *) echo 'Usage: scripts/build.sh [all|homepage|blog|uses|computer]' >&2; exit 2;; esac
mkdir -p .build
node scripts/build-routing.mjs
if [[ "$site" == all || "$site" == homepage ]]; then
  rm -rf .build/homepage
  npm --prefix sites/mads-hartmann.com ci --ignore-scripts
  node sites/mads-hartmann.com/build.mjs "$PWD/.build/homepage"
fi
if [[ "$site" == all || "$site" == uses ]]; then
  rm -rf .build/uses
  npm --prefix sites/uses.mads-hartmann.com ci --ignore-scripts
  node sites/uses.mads-hartmann.com/build.mjs "$PWD/.build/uses"
fi
if [[ "$site" == all || "$site" == computer ]]; then
  rm -rf .build/computer
  npm --prefix sites/computer.mads-hartmann.com ci --ignore-scripts
  node sites/computer.mads-hartmann.com/build.mjs "$PWD/.build/computer"
fi
if [[ "$site" == all || "$site" == blog ]]; then
  root="$PWD"
  # Keep feeds/sitemaps reproducible for a given source commit.
  build_time="$(git log -1 --format=%cI -- sites/blog.mads-hartmann.com scripts/build.sh)"
  printf 'time: %s\n' "$build_time" > .build/jekyll.yml
  cd sites/blog.mads-hartmann.com
  npm ci --ignore-scripts
  bundle check || bundle install
  bundle exec jekyll build --source src --destination "$root/.build/blog" --config "src/_config.yml,$root/.build/jekyll.yml" --strict_front_matter
fi

# Run after all generators (including Jekyll) have written their final output.
cd "$root"
npm --prefix scripts ci --ignore-scripts
for built_site in homepage blog uses computer; do
  if [[ "$site" == all || "$site" == "$built_site" ]]; then
    node scripts/fingerprint-assets.mjs ".build/$built_site"
  fi
done
