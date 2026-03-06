SHELL = /bin/bash

.DEFAULT_GOAL := help
.PHONY: dev test lint start dev_build dev_start dev_test venv go_run go_test go_fmt go_lint go_cover migrate-up migrate-down migrate-status migrate-data

GOOSE_VERSION ?= v3.26.0
SQLITE_DB_PATH ?= bot.db


build:  ## Build all
	docker-compose -f docker-compose-dev.yml build

up:  ## Up All and show logs
	docker-compose -f docker-compose-dev.yml up -d && docker-compose -f docker-compose-dev.yml logs -f --tail=10

update:  ## Restart bot after files changing
	docker-compose -f docker-compose-dev.yml restart bot && make up

stop:  ## Stop all
	docker-compose -f docker-compose-dev.yml stop

down:  ## Down all
	docker-compose -f docker-compose-dev.yml down

test:  ## Run tests locally
	export PYTHONPATH=./bot && pytest bot/tests

go_run: ## Run Go bot
	go run ./cmd/nyanbot

go_test: ## Run Go tests
	go test ./...

go_fmt: ## Format Go code
	gofmt -w ./cmd ./internal

go_lint: ## Run Go linters locally
	go install mvdan.cc/gofumpt@latest
	go install honnef.co/go/tools/cmd/staticcheck@latest
	go install golang.org/x/vuln/cmd/govulncheck@latest
	gofumpt -l ./cmd ./internal
	staticcheck ./...
	govulncheck ./...

go_cover: ## Run Go tests with coverage profile
	go test -coverprofile=coverage.out ./...

migrate-up: ## Apply SQLite migrations (goose)
	go run github.com/pressly/goose/v3/cmd/goose@$(GOOSE_VERSION) -dir db/migrations sqlite3 "$(SQLITE_DB_PATH)" up

migrate-down: ## Roll back one SQLite migration (goose)
	go run github.com/pressly/goose/v3/cmd/goose@$(GOOSE_VERSION) -dir db/migrations sqlite3 "$(SQLITE_DB_PATH)" down

migrate-status: ## Show SQLite migration status (goose)
	go run github.com/pressly/goose/v3/cmd/goose@$(GOOSE_VERSION) -dir db/migrations sqlite3 "$(SQLITE_DB_PATH)" status

migrate-data: ## Copy data between SQLite files
	SOURCE_SQLITE_DB_PATH="$(SOURCE_SQLITE_DB_PATH)" TARGET_SQLITE_DB_PATH="$(TARGET_SQLITE_DB_PATH)" go run ./cmd/nyan-migrate

test_docker:  ## Run tests in docker
	docker-compose -f docker-compose-dev.yml run --rm bot pytest bot/tests

lint:  ## Run linters (black, flake8, mypy, pylint)
	black ./bot --check --diff
	pylint ./bot --rcfile .pylintrc
	flake8 ./bot --config .flake8 --count --show-source --statistics
	mypy --config-file mypy.ini ./bot
	pyright ./bot

format:  ## Format code (black)
	black ./bot

venv:  ## Create local .venv and install deps (uv)
	python3 -m venv .venv
	. .venv/bin/activate && python -m pip install -U pip
	. .venv/bin/activate && python -m pip install -U uv
	. .venv/bin/activate && uv sync --active --dev --no-install-project

## Help

help: ## Show help message
	@IFS=$$'\n' ; \
	help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##/:/'`); \
	printf "%s\n\n" "Usage: make [task]"; \
	printf "%-20s %s\n" "task" "help" ; \
	printf "%-20s %s\n" "------" "----" ; \
	for help_line in $${help_lines[@]}; do \
		IFS=$$':' ; \
		help_split=($$help_line) ; \
		help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		printf '\033[36m'; \
		printf "%-20s %s" $$help_command ; \
		printf '\033[0m'; \
		printf "%s\n" $$help_info; \
	done
