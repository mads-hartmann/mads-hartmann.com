#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
site="${1:-all}"
case "$site" in all|homepage|blog|uses) ;; *) echo 'Usage: scripts/build.sh [all|homepage|blog|uses]' >&2; exit 2;; esac
mkdir -p .build
node scripts/build-routing.mjs
if [[ "$site" == all || "$site" == homepage ]]; then
  rm -rf .build/homepage
  mkdir -p .build/homepage
  node scripts/build-homepage.mjs
  node scripts/build-markdown.mjs homepage
fi
if [[ "$site" == all || "$site" == uses ]]; then
  rm -rf .build/uses
  npm --prefix sites/uses.mads-hartmann.com ci --ignore-scripts
  node sites/uses.mads-hartmann.com/build.mjs "$PWD/.build/uses"
  node scripts/build-markdown.mjs uses
fi
if [[ "$site" == all || "$site" == blog ]]; then
  root="$PWD"
  # Keep feeds/sitemaps reproducible for a given source commit.
  build_time="$(git log -1 --format=%cI -- sites/blog.mads-hartmann.com scripts/build.sh)"
  printf 'time: %s\n' "$build_time" > .build/jekyll.yml
  cd sites/blog.mads-hartmann.com
  bundle check || bundle install
  bundle exec jekyll build --source src --destination "$root/.build/blog" --config "src/_config.yml,$root/.build/jekyll.yml" --strict_front_matter
  cd "$root"
  node scripts/build-markdown.mjs blog
fi
