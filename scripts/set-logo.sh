#!/usr/bin/env bash
#
# set-logo.sh — troca a imagem usada como logo no fastfetch
# Uso: ./scripts/set-logo.sh /caminho/para/nova-foto.jpg
#
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Uso: $0 /caminho/para/imagem.jpg"
    exit 1
fi

SRC_IMG="$1"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
DEST_IMG="$CONFIG_DIR/logo.jpg"

if [ ! -f "$SRC_IMG" ]; then
    echo "Arquivo não encontrado: $SRC_IMG"
    exit 1
fi

mkdir -p "$CONFIG_DIR"
cp "$SRC_IMG" "$DEST_IMG"
echo "✓ Logo atualizado: $DEST_IMG"
echo "  Rode 'fastfetch' pra conferir."
