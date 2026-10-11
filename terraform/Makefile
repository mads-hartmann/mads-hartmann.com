SHELL := bash
.DEFAULT_GOAL := help

.PHONY: help fmt lint check

help:
	@echo 'Targets: fmt, lint (format check), check (build sites, validate and test Terraform)'

fmt:
	terraform fmt -recursive kernel stacks modules

lint:
	terraform fmt -check -recursive kernel stacks modules

check:
	$(MAKE) -C .. check-terraform
