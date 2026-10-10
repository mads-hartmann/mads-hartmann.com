SHELL := bash
.DEFAULT_GOAL := help

.PHONY: help setup build build-routing check check-sites check-terraform check-workflows lint dev dev-homepage dev-blog dev-uses

help:
	@echo 'Targets: setup, build, check (or lint), dev'
	@echo 'Site commands: make -C sites/<site> build|dev|check'
	@echo 'Infrastructure commands: make -C terraform fmt|lint|check'

setup:
	$(MAKE) -C sites/mads-hartmann.com setup
	$(MAKE) -C sites/blog.mads-hartmann.com setup
	$(MAKE) -C sites/uses.mads-hartmann.com setup

build:
	$(MAKE) -C sites/blog.mads-hartmann.com setup
	./scripts/build.sh

build-routing:
	node scripts/build-routing.mjs

check: check-sites check-terraform check-workflows

lint: check

check-sites: build
	node scripts/check-sites.mjs
	cd sites/blog.mads-hartmann.com && bundle exec ruby test/markdown_output_test.rb

check-terraform: build
	./scripts/check-terraform.sh

check-workflows:
	./scripts/check-workflows.sh

dev:
	$(MAKE) -j3 dev-homepage dev-blog dev-uses

dev-homepage:
	$(MAKE) -C sites/mads-hartmann.com dev

dev-blog:
	$(MAKE) -C sites/blog.mads-hartmann.com dev

dev-uses:
	$(MAKE) -C sites/uses.mads-hartmann.com dev
