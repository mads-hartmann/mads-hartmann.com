SHELL := bash
.DEFAULT_GOAL := help
USES_PORT ?= 8081

.PHONY: help setup build dev serve check lint

help:
	@echo 'Targets: setup, build, dev, serve, check (or lint); USES_PORT=8081'

setup:
	npm ci --ignore-scripts --no-audit --no-fund

build:
	../../scripts/build.sh uses

dev: setup
	watchexec --restart --stop-signal SIGINT --watch index.md --watch build.mjs --watch package.json --watch package-lock.json --watch ../shared/footer --watch ../../scripts --watch Makefile -- $(MAKE) serve

serve: build
	python3 -m http.server "$(USES_PORT)" --bind 127.0.0.1 --directory ../../.build/uses

# Shared footer and redirect checks need artifacts from all three sites.
check:
	$(MAKE) -C ../.. check-sites

lint: check
