SERVICE_PLAN_NAME='Private Postgres'
# Load variables from .env if it exists
ifneq (,$(wildcard .env))
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: install-ctl
install-ctl:
	@brew install omnistrate/tap/omnistrate-ctl

.PHONY: upgrade-ctl
upgrade-ctl:
	@brew upgrade omnistrate/tap/omnistrate-ctl

.PHONY: login
login:
	cat ./.omnistrate.password | omnistrate-ctl login --email $(OMNISTRATE_EMAIL) --password-stdin

.PHONY: build
build:
	omnistrate-ctl build -f service-plan-spec.yaml --name $(SERVICE_PLAN_NAME) --spec-type ServicePlanSpec --release-as-preferred