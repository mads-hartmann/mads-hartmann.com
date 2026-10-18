SHELL := bash
.DEFAULT_GOAL := help

.PHONY: help setup build build-routing check check-sites check-terraform check-workflows lint dev dev-homepage dev-blog dev-uses dev-computer

help:
	@echo 'Targets: setup, build, check (or lint), dev'
	@echo 'Site commands: make -C sites/<site> build|dev|check'
	@echo 'Infrastructure commands: make -C terraform fmt|lint|check'

setup:
	bazel fetch //:sites

build:
	./scripts/build.sh

build-routing:
	node scripts/build-routing.mjs

check: check-sites check-terraform

lint: check

check-sites:
	bazel test //...

check-terraform: build
	./scripts/check-terraform.sh

check-workflows:
	./scripts/check-workflows.sh

dev:
	$(MAKE) -j4 dev-homepage dev-blog dev-uses dev-computer

dev-homepage:
	$(MAKE) -C sites/mads-hartmann.com dev

dev-blog:
	$(MAKE) -C sites/blog.mads-hartmann.com dev

dev-uses:
	$(MAKE) -C sites/uses.mads-hartmann.com dev

dev-computer:
	$(MAKE) -C sites/computer.mads-hartmann.com dev
