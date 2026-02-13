.PHONY: setup up down logs ps help build clean restart

# Variables
DOCKER_COMPOSE_FILE := docker-compose.yml
SHELL := /bin/bash
COMPOSE_CMD := docker-compose -f $(DOCKER_COMPOSE_FILE)

# ═══════════════════════════════════════════════════════════════════════════
# 🎯 TARGETS PRINCIPALES
# ═══════════════════════════════════════════════════════════════════════════

help:
	@echo "╔════════════════════════════════════════════════════════════════╗"
	@echo "║   🐳 Docker Guacamole - Makefile                             ║"
	@echo "╚════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📋 COMANDOS PRINCIPALES:"
	@grep -E "^(setup|up|down):" $(MAKEFILE_LIST) | awk -F'##' '{printf "  %-15s → %s\n", substr($$1, 0, index($$1, ":")-1), $$2}' | column -t -s'→'
	@echo ""
	@echo "📊 MONITOREO:"
	@grep -E "^(logs|ps):" $(MAKEFILE_LIST) | awk -F'##' '{printf "  %-15s → %s\n", substr($$1, 0, index($$1, ":")-1), $$2}' | column -t -s'→'
	@echo ""
	@echo "🔧 OTROS:"
	@grep -E "^(build|restart|clean):" $(MAKEFILE_LIST) | awk -F'##' '{printf "  %-15s → %s\n", substr($$1, 0, index($$1, ":")-1), $$2}' | column -t -s'→'
	@echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 🚀 SETUP INICIAL
# ═══════════════════════════════════════════════════════════════════════════

setup: check-docker check-.env generate-secrets build init-db done-setup ## Configurar el proyecto (génera secretos, construye, inicializa BD)
	@echo ""
	@echo "✅ Setup completado exitosamente"
	@echo ""
	@echo "📝 Próximos pasos:"
	@echo "  1. Editar .env con tus valores personalizados (DOMAIN, ACME_EMAIL)"
	@echo "  2. Ejecutar: make up"
	@echo ""

check-docker: ## Verificar que Docker esté instalado
	@echo "🐳 Verificando Docker..."
	@docker --version > /dev/null 2>&1 || (echo "❌ Docker no está instalado"; exit 1)
	@docker-compose --version > /dev/null 2>&1 || (echo "❌ Docker Compose no está instalado"; exit 1)
	@echo "✅ Docker listo"

check-.env: ## Verificar y crear .env
	@echo "📝 Verificando configuración..."
	@if [ ! -f .env ]; then \
		if [ -f .env.guacamole ]; then \
			cp .env.guacamole .env; \
			echo "📝 .env creado desde .env.guacamole"; \
			echo "✅ Configuración lista (actualizada por generate-secrets)"; \
		else \
			echo "❌ No se encontró .env ni .env.guacamole"; \
			exit 1; \
		fi; \
	else \
		echo "✅ .env encontrado"; \
	fi

generate-secrets: ## Generar secretos seguros
	@echo "🔐 Generando secretos..."
	@if [ ! -x generate-secrets.sh ]; then \
		chmod +x generate-secrets.sh; \
	fi
	@echo ""
	@./generate-secrets.sh
	@echo ""
	@echo "⚠️  Ahora edita .env.guacamole y cambia DOMAIN, ACME_EMAIL si es necesario"

build: ## Construir imágenes Docker
	@echo "🔨 Construyendo imágenes Docker..."
	@$(COMPOSE_CMD) build --no-cache
	@echo "✅ Imágenes construidas"

init-db: ## Inicializar base de datos de Guacamole
	@echo "🔧 Inicializando base de datos..."
	@echo "⏳ Levantando servicios temporalmente..."
	@$(COMPOSE_CMD) up -d
	@echo "⏳ Esperando a que los servicios estén listos (esto puede tardar 30-60 segundos)..."
	@sleep 15
	@echo "⏳ Inicializando Guacamole..."
	@chmod +x init-guacamole.sh
	@./init-guacamole.sh || true
	@echo "⏳ Deteniendo servicios..."
	@$(COMPOSE_CMD) down
	@echo "✅ Base de datos inicializada"

done-setup: ## (interno)
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ═══════════════════════════════════════════════════════════════════════════
# 🎮 CONTROLES PRINCIPALES
# ═══════════════════════════════════════════════════════════════════════════

up: ## Levantar todos los servicios
	@echo "🚀 Levantando servicios..."
	@$(COMPOSE_CMD) up -d
	@echo "✅ Servicios levantados"
	@echo ""
	@echo "📋 Estado de servicios:"
	@$(COMPOSE_CMD) ps
	@echo ""
	@echo "🔗 Accede a:"
	@if [ -f .env ]; then \
		DOMAIN=$$(grep '^DOMAIN=' .env | cut -d'=' -f2); \
		echo "  - Guacamole: https://guacamole.$$DOMAIN"; \
		echo "  - Traefik:   https://traefik.$$DOMAIN"; \
		echo "  - Authelia:  https://authelia.$$DOMAIN"; \
	else \
		echo "  (Configura DOMAIN en .env)"; \
	fi

down: ## Detener los servicios
	@echo "🛑 Deteniendo servicios..."
	@$(COMPOSE_CMD) down
	@echo "✅ Servicios detenidos"

# ═══════════════════════════════════════════════════════════════════════════
# 📊 MONITOREO
# ═══════════════════════════════════════════════════════════════════════════

logs: ## Ver logs en tiempo real de todos los servicios
	@echo "📜 Mostrando logs (Ctrl+C para salir)..."
	@$(COMPOSE_CMD) logs -f

ps: ## Mostrar estado de los contenedores
	@echo "📦 Estado de contenedores:"
	@$(COMPOSE_CMD) ps

# ═══════════════════════════════════════════════════════════════════════════
# 🔧 MANTENIMIENTO
# ═══════════════════════════════════════════════════════════════════════════

restart: down ## Reiniciar todos los servicios
	@echo "🔄 Reiniciando servicios..."
	@$(COMPOSE_CMD) up -d
	@echo "✅ Servicios reiniciados"

clean: ## Eliminar volúmenes y datos (¡IRREVERSIBLE!)
	@echo "⚠️  Advertencia: Esto eliminará TODOS los volúmenes y datos"
	@read -p "¿Estás seguro? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "🗑️  Eliminando volúmenes..."; \
		$(COMPOSE_CMD) down -v; \
		rm -f .env.secrets; \
		echo "✅ Limpieza completada"; \
	else \
		echo "❌ Operación cancelada"; \
	fi

.DEFAULT_GOAL := help
