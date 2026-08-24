.PHONY: all help shell packages source claude git starship recovery fonts kitty

DOTFILES_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)

all: packages fonts source claude git starship shell  ## Instalar todo

help:  ## Mostrar ayuda
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

packages:  ## Instalar paquetes del sistema + Docker + Starship
	bash $(DOTFILES_DIR)/scripts/install_packages.sh

source:  ## Instalar FZF, FNM y Kitty desde source (FNM y Kitty opcionales)
	bash $(DOTFILES_DIR)/scripts/install_from_source.sh

fonts:  ## Instalar JetBrains Mono Nerd Font
	bash $(DOTFILES_DIR)/scripts/install_fonts.sh

recovery:  ## Configurar resiliencia del sistema (zram, earlyoom, sysrq)
	bash $(DOTFILES_DIR)/scripts/install_system_recovery.sh

claude:  ## Configurar Claude Code + Cursor
	bash $(DOTFILES_DIR)/scripts/install_claude.sh

git:  ## Enlazar .gitconfig, gitignore.global y configurar datos personales
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
	@if [ -L "$(HOME)/.gitignore" ] && [ "$$(readlink -f "$(HOME)/.gitignore")" = "$$(readlink -f "$(DOTFILES_DIR)/git/gitignore.global")" ]; then \
		echo "\033[1;33m↔  .gitignore ya está enlazado — skip\033[0m"; \
	else \
		if [ -e "$(HOME)/.gitignore" ] || [ -L "$(HOME)/.gitignore" ]; then \
			BACKUP="$(HOME)/.gitignore.bak.$$(date +%Y%m%d%H%M%S)"; \
			echo "\033[1;33m📦 Backup de .gitignore → $$BACKUP\033[0m"; \
			mv "$(HOME)/.gitignore" "$$BACKUP"; \
		fi; \
		ln -sf "$(DOTFILES_DIR)/git/gitignore.global" "$(HOME)/.gitignore"; \
		echo "\033[0;32m✅ .gitignore (gitignore.global) enlazado\033[0m"; \
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

kitty:  ## Enlazar config/kitty/kitty.conf (opt-in — instala kitty con `make source`)
	@mkdir -p "$(HOME)/.config/kitty"
	@if [ -L "$(HOME)/.config/kitty/kitty.conf" ] && [ "$$(readlink -f "$(HOME)/.config/kitty/kitty.conf")" = "$$(readlink -f "$(DOTFILES_DIR)/config/kitty/kitty.conf")" ]; then \
		echo "\033[1;33m↔  kitty.conf ya está enlazado — skip\033[0m"; \
	else \
		if [ -e "$(HOME)/.config/kitty/kitty.conf" ] || [ -L "$(HOME)/.config/kitty/kitty.conf" ]; then \
			BACKUP="$(HOME)/.config/kitty/kitty.conf.bak.$$(date +%Y%m%d%H%M%S)"; \
			echo "\033[1;33m📦 Backup de kitty.conf → $$BACKUP\033[0m"; \
			mv "$(HOME)/.config/kitty/kitty.conf" "$$BACKUP"; \
		fi; \
		ln -sf "$(DOTFILES_DIR)/config/kitty/kitty.conf" "$(HOME)/.config/kitty/kitty.conf"; \
		echo "\033[0;32m✅ kitty.conf enlazado\033[0m"; \
	fi

shell:  ## Instalar el punto de entrada único de shell en ~/.bashrc
	bash $(DOTFILES_DIR)/scripts/install_shell.sh
