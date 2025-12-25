.PHONY: help init submodules up down build logs ps clean deploy-dev deploy-prod

# Default target
help:
	@echo "OmniMap Platform - Available commands:"
	@echo ""
	@echo "  Setup:"
	@echo "    make init          - Initialize project (submodules + env)"
	@echo "    make submodules    - Update git submodules"
	@echo ""
	@echo "  Local Development (Docker Compose):"
	@echo "    make up            - Start all services"
	@echo "    make down          - Stop all services"
	@echo "    make build         - Build all images"
	@echo "    make logs          - View logs (all services)"
	@echo "    make logs-back     - View omnimap-back logs"
	@echo "    make logs-front    - View omnimap-front logs"
	@echo "    make logs-sync     - View omnimap-sync logs"
	@echo "    make logs-llm      - View llm-gateway logs"
	@echo "    make ps            - Show running containers"
	@echo "    make clean         - Remove containers and volumes"
	@echo ""
	@echo "  Kubernetes Deployment:"
	@echo "    make deploy-dev    - Deploy to dev environment"
	@echo "    make deploy-prod   - Deploy to production"
	@echo "    make k8s-status    - Show K8s deployment status"
	@echo ""

# =============================================================================
# Setup
# =============================================================================

init: submodules
	@echo "Creating .env file..."
	@cp -n infrastructure/.env.example infrastructure/.env 2>/dev/null || true
	@echo "Done! Edit infrastructure/.env with your settings."

submodules:
	@echo "Initializing submodules..."
	git submodule update --init --recursive
	@echo "Submodules updated."

# =============================================================================
# Local Development (Docker Compose)
# =============================================================================

COMPOSE_FILE = infrastructure/docker-compose.yml

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down

build:
	docker compose -f $(COMPOSE_FILE) build

logs:
	docker compose -f $(COMPOSE_FILE) logs -f

logs-back:
	docker compose -f $(COMPOSE_FILE) logs -f omnimap-back

logs-front:
	docker compose -f $(COMPOSE_FILE) logs -f omnimap-front

logs-sync:
	docker compose -f $(COMPOSE_FILE) logs -f omnimap-sync

logs-llm:
	docker compose -f $(COMPOSE_FILE) logs -f llm-gateway

ps:
	docker compose -f $(COMPOSE_FILE) ps

clean:
	docker compose -f $(COMPOSE_FILE) down -v --remove-orphans
	docker system prune -f

# Start only infrastructure (postgres, redis, rabbitmq)
infra:
	docker compose -f $(COMPOSE_FILE) up -d postgres redis rabbitmq

# Restart a specific service
restart-%:
	docker compose -f $(COMPOSE_FILE) restart $*

# =============================================================================
# Kubernetes Deployment
# =============================================================================

K8S_BASE = deploy/kubernetes

deploy-dev:
	kubectl apply -k $(K8S_BASE)/overlays/dev

deploy-prod:
	@echo "WARNING: Deploying to production!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	kubectl apply -k $(K8S_BASE)/overlays/prod

k8s-status:
	kubectl get pods -n omnimap
	@echo ""
	kubectl get svc -n omnimap
	@echo ""
	kubectl get ingress -n omnimap

k8s-logs-%:
	kubectl logs -n omnimap -l app=$* -f

# =============================================================================
# Development Utilities
# =============================================================================

# Run migrations for omnimap-back
migrate:
	docker compose -f $(COMPOSE_FILE) exec omnimap-back python manage.py migrate

# Create superuser
superuser:
	docker compose -f $(COMPOSE_FILE) exec omnimap-back python manage.py createsuperuser

# Shell into a service
shell-back:
	docker compose -f $(COMPOSE_FILE) exec omnimap-back /bin/sh

shell-llm:
	docker compose -f $(COMPOSE_FILE) exec llm-gateway /bin/sh
