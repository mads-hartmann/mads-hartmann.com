SHELL := bash
.DEFAULT_GOAL := help
HOMEPAGE_PORT ?= 8080

.PHONY: help setup build dev check lint

help:
	@echo 'Targets: build, dev, check (or lint); HOMEPAGE_PORT=8080'

setup:
	@echo 'Homepage has no dependencies to install.'

build:
	../../scripts/build.sh homepage

dev:
	watchexec --restart --stop-signal SIGINT \
		--watch src --watch ../shared/footer --watch ../../routing --watch ../../scripts --watch Makefile \
		-- '$(MAKE) build && exec python3 -m http.server "$(HOMEPAGE_PORT)" --bind 127.0.0.1 --directory ../../.build/homepage'

# Shared footer and redirect checks need artifacts from all three sites.
check:
	$(MAKE) -C ../.. check-sites

lint: check
