#!/bin/bash

# Estas opciones (shopt, historial) solo tienen sentido en una shell
# interactiva — un rc recién creado por scripts/install_shell.sh no
# lleva el early-return de Debian/Ubuntu, así que este fichero se
# guarda a sí mismo en vez de depender de él.
[[ $- == *i* ]] || return 0

# ============================================
# Opciones de bash interactivo
# ============================================
# Estas 4 primeras vienen apagadas por defecto en Debian/Ubuntu y
# sustituyen funciones que se echan de menos al venir de zsh:
#   autocd    - escribir un directorio a secas equivale a `cd directorio`
#   globstar  - `**` expande recursivamente en globs (p.ej. `ls **/*.ts`)
#   cdspell   - corrige pequeños typos en el argumento de `cd`
#   dirspell  - corrige typos también al autocompletar nombres de directorio
# El resto ya viene activado en el .bashrc de Debian/Ubuntu, se repite
# aquí para que la configuración de shell no dependa de ese fichero:
#   histappend    - añade al historial en vez de sobrescribirlo
#   checkwinsize  - recalcula LINES/COLUMNS tras cada comando
shopt -s autocd globstar cdspell dirspell histappend checkwinsize

# ============================================
# Historial
# ============================================
export HISTSIZE=10000
export HISTFILESIZE=20000
# ignoreboth = ignoredups + ignorespace (en la lista en memoria de la
# sesión actual). erasedups hace lo mismo con duplicados no consecutivos
# de esa misma lista en memoria — junto con histappend (que AÑADE al
# HISTFILE en vez de reescribirlo), esto NO deduplica lo ya persistido
# en disco entre sesiones, solo la lista de la sesión en curso.
export HISTCONTROL=ignoreboth:erasedups
