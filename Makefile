DOCKER ?= kiri
export DOCKER

# A stack is any directory holding a compose.yaml, at the repo root or one
# level below it. Discovery is deliberately shallow: `smoke`, `smoke/redis`
# yes; `smoke/redis/extra` no.
STACKS := $(sort $(patsubst %/compose.yaml,%,$(wildcard */compose.yaml */*/compose.yaml)))

TARGETS := list up down restart ps logs check shell clean help

# Stack selection, in order of precedence:
#   make up smoke/redis      (positional)
#   make up STACK=smoke/redis (explicit variable)
#   make up                  (only if the repo holds exactly one stack)
STACK_ARG := $(filter-out $(TARGETS),$(MAKECMDGOALS))
ifeq ($(origin STACK),undefined)
  STACK := $(STACK_ARG)
endif
STACK_EXPLICIT := $(strip $(or $(STACK_ARG),$(if $(filter command line environment,$(origin STACK)),$(STACK))))
# Tolerate `smoke/`, `./smoke`, and a bare `.` for the current directory.
STACK := $(patsubst ./%,%,$(patsubst %/,%,$(strip $(STACK))))
DIR := $(if $(filter .,$(STACK)),.,$(STACK))
COMPOSE := cd $(DIR) && $(DOCKER) compose

ifeq ($(strip $(STACK)),)
  ifeq ($(words $(STACKS)),1)
    STACK := $(firstword $(STACKS))
    DIR := $(STACK)
    COMPOSE := cd $(DIR) && $(DOCKER) compose
  endif
endif

# Validate up front so recipes stay free of shell quoting noise.
NEEDS_STACK := $(filter up down restart logs check shell clean,$(MAKECMDGOALS))
ifneq ($(strip $(STACK)),)
  ifeq ($(wildcard $(DIR)/compose.yaml),)
    $(error no stack at "$(STACK)" (no compose.yaml)$(if $(STACKS), | available: $(STACKS),))
  endif
else ifneq ($(strip $(NEEDS_STACK)),)
  $(error usage: make $(firstword $(NEEDS_STACK)) <stack-path> | available: $(if $(STACKS),$(STACKS),none))
endif

# Swallow the positional argument so make does not treat it as a build goal.
ifneq ($(STACK_ARG),)
.PHONY: $(STACK_ARG)
$(STACK_ARG):
	@:
endif

.PHONY: list up down restart ps logs check shell clean help

help: ## show this help
	@sed -n 's/^\([a-z-]*\):.*## \(.*\)/  \1 - \2/p' Makefile

list: ## list stacks in the repo
	@for s in $(STACKS); do printf '  %s\n' "$$s"; done

up: ## start STACK and wait for healthchecks
	$(COMPOSE) up -d --wait

down: ## stop and remove STACK's containers + network
	$(COMPOSE) down

restart: ## recreate STACK from scratch
	$(COMPOSE) down && $(COMPOSE) up -d --wait

ps: ## container status (every stack when no stack is given)
	@if [ -n "$(STACK_EXPLICIT)" ]; then \
		cd $(DIR) && $(DOCKER) compose ps; \
	else \
		for s in $(STACKS); do \
			printf '\n\033[1m%s\033[0m\n' "$$s"; \
			(cd "$$s" && $(DOCKER) compose ps) || true; \
		done; \
	fi

logs: ## follow STACK logs
	$(COMPOSE) logs -f --tail=50

check: ## run STACK's check.sh (if present)
	@cd $(DIR) && if [ -x ./check.sh ]; then ./check.sh; else echo "no check.sh in $(DIR)"; fi

shell: ## open a shell in STACK's app container
	$(COMPOSE) exec app sh

clean: ## remove STACK's containers, network, and volumes
	$(COMPOSE) down -v --remove-orphans
