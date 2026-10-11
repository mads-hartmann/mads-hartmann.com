SHELL := bash
.DEFAULT_GOAL := help
BLOG_PORT ?= 4000

.PHONY: help setup build dev serve check lint

help:
	@echo 'Targets: setup, build, dev, serve, check (or lint); BLOG_PORT=4000'

setup:
	../../scripts/setup-blog.sh

build: setup
	../../scripts/build.sh blog

dev: setup
	watchexec --restart --stop-signal SIGINT --watch src --watch Gemfile --watch Gemfile.lock --watch ../shared/footer --watch ../../scripts --watch Makefile -- $(MAKE) serve

serve: setup
	bundle exec jekyll serve --no-watch --disable-disk-cache --drafts --source src --destination ../../.build/blog-preview --host 127.0.0.1 --port "$(BLOG_PORT)"

# Shared footer and redirect checks need artifacts from all three sites.
check:
	$(MAKE) -C ../.. check-sites

lint: check
