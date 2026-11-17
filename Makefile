DOCKER ?= kiri
TEST ?= smoke
DIR := tests/$(TEST)
COMPOSE := cd $(DIR) && $(DOCKER) compose

.PHONY: list up down restart ps logs check shell clean

list: ## show available tests
	@ls -1 tests

up: ## start TEST and wait for healthchecks
	$(COMPOSE) up -d --wait

down: ## stop and remove TEST containers + network
	$(COMPOSE) down

restart: ## recreate TEST from scratch
	$(COMPOSE) down && $(COMPOSE) up -d --wait

ps: ## container status for TEST
	$(COMPOSE) ps

logs: ## follow logs for TEST
	$(COMPOSE) logs -f --tail=50

check: ## assert TEST endpoints respond
	@cd $(DIR) && ./check.sh

shell: ## open a shell in TEST's app container
	$(COMPOSE) exec app sh

clean: ## remove TEST containers, network, and volumes
	$(COMPOSE) down -v --remove-orphans
