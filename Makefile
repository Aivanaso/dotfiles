.PHONY: all help shell packages source claude git starship

DOTFILES_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)

all: packages source claude git starship shell  ## Instalar todo

help:  ## Mostrar ayuda
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

packages:  ## Instalar paquetes del sistema + Docker + Starship
	bash $(DOTFILES_DIR)/scripts/install_packages.sh

source:  ## Instalar FZF y FNM desde source
	bash $(DOTFILES_DIR)/scripts/install_from_source.sh

claude:  ## Configurar Claude Code + Cursor
	bash $(DOTFILES_DIR)/scripts/install_claude.sh

git:  ## Enlazar .gitconfig y configurar datos personales
	@if [ -L "$(HOME)/.gitconfig" ] && [ "$$(readlink -f "$(HOME)/.gitconfig")" = "$$(readlink -f "$(DOTFILES_DIR)/git/.gitconfig")" ]; then \
		echo "\033[1;33m↔  .gitconfig ya está enlazado — skip\033[0m"; \
	else \
		if [ -e "$(HOME)/.gitconfig" ] || [ -L "$(HOME)/.gitconfig" ]; then \
			BACKUP="$(HOME)/.gitconfig.bak.$$(date +%Y%m%d%H%M%S)"; \
			echo "\033[1;33m📦 Backup de .gitconfig → $$BACKUP\033[0m"; \
			mv "$(HOME)/.gitconfig" "$$BACKUP"; \
		fi; \
		ln -sf "$(DOTFILES_DIR)/git/.gitconfig" "$(HOME)/.gitconfig"; \
		echo "\033[0;32m✅ .gitconfig enlazado\033[0m"; \
	fi
	@if [ ! -f "$(HOME)/.gitconfig.local" ]; then \
		echo "\033[1;33m👤 Configurando datos personales de Git...\033[0m"; \
		read -rp "   Nombre: " git_name; \
		read -rp "   Email:  " git_email; \
		printf "[user]\n    name = %s\n    email = %s\n" "$$git_name" "$$git_email" > "$(HOME)/.gitconfig.local"; \
		echo "\033[0;32m✅ ~/.gitconfig.local creado\033[0m"; \
	else \
		echo "\033[1;33m↔  ~/.gitconfig.local ya existe — skip\033[0m"; \
	fi

starship:  ## Enlazar starship.toml
	@mkdir -p "$(HOME)/.config"
	@if [ -L "$(HOME)/.config/starship.toml" ] && [ "$$(readlink -f "$(HOME)/.config/starship.toml")" = "$$(readlink -f "$(DOTFILES_DIR)/config/starship.toml")" ]; then \
		echo "\033[1;33m↔  starship.toml ya está enlazado — skip\033[0m"; \
	else \
		if [ -e "$(HOME)/.config/starship.toml" ] || [ -L "$(HOME)/.config/starship.toml" ]; then \
			BACKUP="$(HOME)/.config/starship.toml.bak.$$(date +%Y%m%d%H%M%S)"; \
			echo "\033[1;33m📦 Backup de starship.toml → $$BACKUP\033[0m"; \
			mv "$(HOME)/.config/starship.toml" "$$BACKUP"; \
		fi; \
		ln -sf "$(DOTFILES_DIR)/config/starship.toml" "$(HOME)/.config/starship.toml"; \
		echo "\033[0;32m✅ starship.toml enlazado\033[0m"; \
	fi

shell:  ## Mostrar cómo cargar shell config
	@echo ""
	@echo "Añade a tu .bashrc o .zshrc:"
	@echo ""
	@echo "  source $(DOTFILES_DIR)/shell/exports.sh"
	@echo "  source $(DOTFILES_DIR)/shell/aliases.sh"
	@echo "  source $(DOTFILES_DIR)/shell/functions.sh"
	@echo "  source $(DOTFILES_DIR)/shell/prompt.sh"
	@echo ""
