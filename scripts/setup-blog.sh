#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../sites/blog.mads-hartmann.com"
bundle check && exit 0
gem install bundler --version "$(awk '/^BUNDLED WITH$/{getline; print $1}' Gemfile.lock)" --no-document
# This gem has both mkmf and Rake extensions; Rake rejects Bundler's build flags.
if [[ "$(< Gemfile.lock)" == *"    google-protobuf (3.25.2)"* ]] &&
  ! gem list --installed --exact google-protobuf --version 3.25.2 >/dev/null; then
  CONFIGURE_ARGS="${CONFIGURE_ARGS:-} --with-cflags=-Wno-error=format-security" \
    gem install google-protobuf --version 3.25.2 --platform ruby --no-document
fi
bundle install
