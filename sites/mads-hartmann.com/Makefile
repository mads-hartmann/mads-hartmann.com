SHELL := bash
.DEFAULT_GOAL := help
HOMEPAGE_PORT ?= 8080

.PHONY: help setup build dev check lint

help:
	@echo 'Targets: setup, build, dev, check (or lint); HOMEPAGE_PORT=8080'

setup:
	npm ci --ignore-scripts --no-audit --no-fund

build:
	../../scripts/build.sh homepage

dev:
	watchexec --restart --stop-signal SIGINT \
		--watch src --watch llms.txt --watch robots.txt --watch sitemap.xml --watch build.mjs --watch package.json --watch package-lock.json \
		--watch ../shared/footer --watch ../../routing --watch ../../scripts --watch Makefile \
		-- '$(MAKE) build && exec python3 -m http.server "$(HOMEPAGE_PORT)" --bind 127.0.0.1 --directory ../../.build/homepage'

# Shared footer and redirect checks need artifacts from all three sites.
check:
	$(MAKE) -C ../.. check-sites

lint: check
