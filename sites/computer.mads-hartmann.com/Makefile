SHELL := bash
.DEFAULT_GOAL := help
COMPUTER_PORT ?= 8082

.PHONY: help setup build dev check lint

help:
	@echo 'Targets: setup, build, dev, check (or lint); COMPUTER_PORT=8082'

setup:
	npm ci --ignore-scripts --no-audit --no-fund

build:
	../../scripts/build.sh computer

dev:
	watchexec --restart --stop-signal SIGINT \
		--watch index.md --watch v1.md --watch v2.md --watch v3.md --watch llms.txt --watch robots.txt --watch sitemap.xml --watch build.mjs --watch package.json --watch package-lock.json --watch ../shared/footer --watch ../../scripts --watch Makefile \
		-- '$(MAKE) build && exec python3 -m http.server "$(COMPUTER_PORT)" --bind 127.0.0.1 --directory ../../.build/computer'

# Shared footer and redirect checks need artifacts from all four sites.
check:
	$(MAKE) -C ../.. check-sites

lint: check
