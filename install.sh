#!/usr/bin/env bash
#
#   _____ _____ _____ _____ _____ _____ _____ _____ _____
#  |   __|  _  |   __|_   _|   __|   __|_   _|     |  |  |
#  |   __|     |__   | | | |   __|   __| | | |   --|     |
#  |__|  |__|__|_____| |_| |__|  |_____| |_| |_____|__|__|
#
#  install.sh — instala e configura kitty + fastfetch (+ extras)
#  Funciona COM ou SEM acesso a sudo: sem root, tudo vai pra ~/.local
#  (binários pré-compilados baixados do GitHub), sem tocar em nada
#  fora da sua pasta pessoal.
#
#  Uso: ./install.sh [--user] [--system] [--no-font] [--no-extras] [--copy]
#
set -euo pipefail

# ---------- cores pro output ----------
c_reset="\033[0m"
c_blue="\033[34m"
c_green="\033[32m"
c_yellow="\033[33m"
c_red="\033[31m"

info()  { echo -e "${c_blue}[*]${c_reset} $1"; }
ok()    { echo -e "${c_green}[✓]${c_reset} $1"; }
warn()  { echo -e "${c_yellow}[!]${c_reset} $1"; }
err()   { echo -e "${c_red}[x]${c_reset} $1"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="$HOME/.local/bin"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BIN_DIR"

# ---------- flags ----------
SKIP_FONT=false
NO_SYMLINK=false
SKIP_EXTRAS=false
FORCE_MODE=""   # "" | user | system

for arg in "$@"; do
    case "$arg" in
        --user)         FORCE_MODE="user" ;;
        --system)       FORCE_MODE="system" ;;
        --no-packages)  FORCE_MODE="user" ;;  # compatibilidade com versões antigas
        --no-font)      SKIP_FONT=true ;;
        --no-extras)    SKIP_EXTRAS=true ;;
        --copy)         NO_SYMLINK=true ;;
        -h|--help)
            echo "Uso: ./install.sh [--user] [--system] [--no-font] [--no-extras] [--copy]"
            echo "  --user          instala tudo em \$HOME/.local, sem sudo (ideal pra PCs de laboratório)"
            echo "  --system        usa o gerenciador de pacotes do sistema (precisa de sudo)"
            echo "  --no-font       não instala a JetBrainsMono Nerd Font"
            echo "  --no-extras     não instala starship/eza/bat/zoxide/fzf"
            echo "  --copy          copia os arquivos de config em vez de criar symlinks"
            exit 0
            ;;
    esac
done

echo ""
info "Instalando dotfiles a partir de: $REPO_DIR"
echo ""

# ---------- 0. decidir o modo de instalação (com ou sem sudo) ----------
MODE=""
if [ -n "$FORCE_MODE" ]; then
    MODE="$FORCE_MODE"
elif ! command -v sudo >/dev/null 2>&1; then
    MODE="user"
    info "'sudo' não encontrado neste sistema."
else
    echo "Esta máquina tem 'sudo' instalado, mas em muitos laboratórios (ex: labs da UFCG) o"
    echo "usuário não tem permissão de usá-lo."
    read -rp "Você TEM acesso a sudo nesta máquina (consegue instalar pacotes com privilégio de root)? [s/N] " resp_sudo
    resp_sudo="${resp_sudo:-n}"
    if [[ "$resp_sudo" =~ ^[Ss]$ ]]; then MODE="system"; else MODE="user"; fi
fi

if [ "$MODE" = "user" ]; then
    ok "Modo escolhido: instalação 100%% em \$HOME/.local — nenhum comando precisa de root."
else
    ok "Modo escolhido: instalação via gerenciador de pacotes do sistema (com sudo)."
fi
echo ""

# ---------- detectar gerenciador de pacotes (só é usado no modo 'system') ----------
PKG_MANAGER=""
if [ "$MODE" = "system" ]; then
    if command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
    elif command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v zypper >/dev/null 2>&1; then
        PKG_MANAGER="zypper"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MANAGER="brew"
    else
        warn "Não consegui detectar um gerenciador de pacotes suportado."
        warn "Vou instalar tudo em modo usuário (sem sudo) mesmo assim."
        MODE="user"
    fi
fi

install_pkg() {
    local pkg="$1"
    info "Instalando '$pkg' via $PKG_MANAGER..."
    case "$PKG_MANAGER" in
        pacman) sudo pacman -S --needed --noconfirm "$pkg" ;;
        apt)    sudo apt update -y && sudo apt install -y "$pkg" ;;
        dnf)    sudo dnf install -y "$pkg" ;;
        zypper) sudo zypper install -y "$pkg" ;;
        brew)   brew install "$pkg" ;;
        *)      return 1 ;;
    esac
}

# ---------- detectar arquitetura (pra baixar o binário certo em modo usuário) ----------
ARCH=""
case "$(uname -m)" in
    x86_64|amd64)  ARCH="amd64" ;;
    aarch64|arm64) ARCH="aarch64" ;;
    *) warn "Arquitetura '$(uname -m)' sem binário pré-compilado conhecido — alguns extras podem falhar." ;;
esac

# ---------- helpers de download em modo usuário ----------
# Baixa um .tar.gz, procura por um binário com nome exato dentro dele e instala em $BIN_DIR
fetch_targz_bin() {
    local url="$1" bin_name="$2" dest_name="${3:-$2}"
    local tmp archive found
    tmp="$(mktemp -d)"
    archive="$tmp/pkg.tar.gz"
    if ! curl -fsSL -o "$archive" "$url" 2>/dev/null; then
        warn "Falha ao baixar: $url"
        rm -rf "$tmp"
        return 1
    fi
    if ! tar xzf "$archive" -C "$tmp" 2>/dev/null; then
        warn "Falha ao extrair o pacote baixado de $url"
        rm -rf "$tmp"
        return 1
    fi
    # Prioriza o binário de verdade: primeiro dentro de um diretório bin/, depois
    # perto da raiz, e só por último qualquer arquivo com esse nome — pacotes como
    # o do fastfetch também trazem um script de autocomplete com o mesmo nome
    # (ex: usr/share/bash-completion/completions/fastfetch), e não queremos pegar esse.
    found="$(find "$tmp" -type f -path "*/bin/$bin_name" 2>/dev/null | head -n1)"
    if [ -z "$found" ]; then
        found="$(find "$tmp" -maxdepth 2 -type f -name "$bin_name" 2>/dev/null | head -n1)"
    fi
    if [ -z "$found" ]; then
        found="$(find "$tmp" -type f -name "$bin_name" \
            ! -path "*/share/*" ! -path "*/completions/*" ! -path "*/man/*" 2>/dev/null | head -n1)"
    fi
    if [ -z "$found" ]; then
        warn "Não encontrei o binário '$bin_name' dentro do pacote baixado."
        rm -rf "$tmp"
        return 1
    fi
    install -m 755 "$found" "$BIN_DIR/$dest_name"
    rm -rf "$tmp"
    ok "'$dest_name' instalado em $BIN_DIR (binário pré-compilado, sem sudo)."
}

# Descobre a tag da última release de um repo do GitHub (ex: sharkdp/bat -> v0.26.1)
get_gh_tag() {
    curl -sI "https://github.com/$1/releases/latest" 2>/dev/null \
        | grep -i '^location:' | sed -E 's#.*/tag/##; s/\r$//'
}

fetch_eza() {
    [ -n "$ARCH" ] || return 1
    local triple
    [ "$ARCH" = "amd64" ] && triple="x86_64-unknown-linux-musl" || triple="aarch64-unknown-linux-gnu"
    fetch_targz_bin "https://github.com/eza-community/eza/releases/latest/download/eza_${triple}.tar.gz" "eza"
}

fetch_bat() {
    [ -n "$ARCH" ] || return 1
    local tag triple
    tag="$(get_gh_tag sharkdp/bat)"
    [ -n "$tag" ] || { warn "Não consegui descobrir a versão mais recente do bat."; return 1; }
    [ "$ARCH" = "amd64" ] && triple="x86_64-unknown-linux-musl" || triple="aarch64-unknown-linux-musl"
    fetch_targz_bin "https://github.com/sharkdp/bat/releases/download/${tag}/bat-${tag}-${triple}.tar.gz" "bat"
}

fetch_fzf() {
    [ -n "$ARCH" ] || return 1
    local tag ver suffix
    tag="$(get_gh_tag junegunn/fzf)"
    [ -n "$tag" ] || { warn "Não consegui descobrir a versão mais recente do fzf."; return 1; }
    ver="${tag#v}"
    [ "$ARCH" = "amd64" ] && suffix="linux_amd64" || suffix="linux_arm64"
    fetch_targz_bin "https://github.com/junegunn/fzf/releases/download/${tag}/fzf-${ver}-${suffix}.tar.gz" "fzf"
}

fetch_fastfetch() {
    [ -n "$ARCH" ] || return 1
    local suffix
    [ "$ARCH" = "amd64" ] && suffix="amd64" || suffix="aarch64"
    fetch_targz_bin "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-${suffix}.tar.gz" "fastfetch"
}

fetch_kitty() {
    info "Baixando o kitty pra \$HOME/.local/kitty.app (instalação própria da kovidgoyal, sem sudo)..."
    local tmp_installer
    tmp_installer="$(mktemp /tmp/kitty-installer-XXXX.sh)"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o "$tmp_installer" https://sw.kovidgoyal.net/kitty/installer.sh || { warn "Falha ao baixar o instalador do kitty."; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$tmp_installer" https://sw.kovidgoyal.net/kitty/installer.sh || { warn "Falha ao baixar o instalador do kitty."; return 1; }
    else
        warn "Sem curl/wget disponível — não deu pra instalar o kitty."
        return 1
    fi
    sh "$tmp_installer" dest="$HOME/.local/kitty.app" launch=n || { warn "Falha ao instalar o kitty."; rm -f "$tmp_installer"; return 1; }
    rm -f "$tmp_installer"
    ln -sf "$HOME/.local/kitty.app/bin/kitty" "$BIN_DIR/kitty"
    ln -sf "$HOME/.local/kitty.app/bin/kitten" "$BIN_DIR/kitten"
    # integra o kitty ao menu de aplicativos (funciona sem root, ~/.local/share é do usuário)
    if [ -d "$HOME/.local/kitty.app/share/applications" ]; then
        mkdir -p "$HOME/.local/share/applications"
        cp "$HOME/.local/kitty.app/share/applications/kitty.desktop" "$HOME/.local/share/applications/" 2>/dev/null || true
        cp "$HOME/.local/kitty.app/share/applications/kitty-open.desktop" "$HOME/.local/share/applications/" 2>/dev/null || true
        sed -i "s|Icon=kitty|Icon=$HOME/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" \
            "$HOME/.local/share/applications/kitty.desktop" 2>/dev/null || true
        sed -i "s|Exec=kitty|Exec=$HOME/.local/kitty.app/bin/kitty|g" \
            "$HOME/.local/share/applications/kitty.desktop" 2>/dev/null || true
    fi
    ok "kitty instalado. Link criado em $BIN_DIR/kitty."
}

# starship e zoxide: os instaladores oficiais deles já não precisam de sudo quando
# apontamos pra uma pasta que o usuário pode escrever, então usamos sempre esse caminho.
fetch_starship() {
    info "Instalando starship em $BIN_DIR (script oficial, sem sudo)..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR" >/dev/null || { warn "Falha ao instalar o starship."; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR" >/dev/null || { warn "Falha ao instalar o starship."; return 1; }
    else
        warn "Sem curl/wget disponível — não deu pra instalar o starship."
        return 1
    fi
    ok "starship instalado em $BIN_DIR."
}

fetch_zoxide() {
    info "Instalando zoxide em $BIN_DIR (script oficial, sem sudo)..."
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null || { warn "Falha ao instalar o zoxide."; return 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh >/dev/null || { warn "Falha ao instalar o zoxide."; return 1; }
    else
        warn "Sem curl/wget disponível — não deu pra instalar o zoxide."
        return 1
    fi
    ok "zoxide instalado em $BIN_DIR."
}

# ---------- instalador genérico: tenta o gerenciador de pacotes, senão baixa o binário ----------
install_tool() {
    local cmd_check="$1" pkg_name="$2" fetch_fn="$3"
    if command -v "$cmd_check" >/dev/null 2>&1; then
        ok "'$cmd_check' já está instalado."
        return
    fi
    if [ "$MODE" = "system" ]; then
        if install_pkg "$pkg_name" && command -v "$cmd_check" >/dev/null 2>&1; then
            ok "'$cmd_check' instalado via $PKG_MANAGER."
            return
        fi
        warn "Não consegui instalar '$pkg_name' com $PKG_MANAGER — baixando binário direto do GitHub..."
    fi
    "$fetch_fn" || err "Não consegui instalar '$cmd_check' automaticamente. Baixe manualmente depois."
}

# ---------- 1. kitty + fastfetch ----------
install_tool kitty kitty fetch_kitty
install_tool fastfetch fastfetch fetch_fastfetch

# ---------- 1b. ferramentas extras (starship, eza, bat, zoxide, fzf) ----------
if [ "$SKIP_EXTRAS" = false ]; then
    echo ""
    read -rp "Instalar também starship, eza, bat, zoxide e fzf (prompt + CLIs modernas)? [S/n] " resp_extras
    resp_extras="${resp_extras:-s}"
    if [[ "$resp_extras" =~ ^[Ss]$ ]]; then
        if command -v starship >/dev/null 2>&1; then ok "'starship' já está instalado."; else fetch_starship || true; fi
        install_tool eza eza fetch_eza
        if command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1; then
            ok "'bat' já está instalado."
        else
            [ "$MODE" = "system" ] && { install_pkg bat || true; }
            if ! command -v bat >/dev/null 2>&1 && ! command -v batcat >/dev/null 2>&1; then
                fetch_bat || err "Não consegui instalar 'bat'."
            fi
        fi
        if command -v zoxide >/dev/null 2>&1; then ok "'zoxide' já está instalado."; else fetch_zoxide || true; fi
        install_tool fzf fzf fetch_fzf
    else
        SKIP_EXTRAS=true
    fi
else
    info "Pulando instalação das ferramentas extras (--no-extras)."
fi

# ---------- 2. Nerd Font (JetBrains Mono) — sempre em modo usuário, nunca precisa de sudo ----------
if [ "$SKIP_FONT" = false ]; then
    FONT_DIR="$HOME/.local/share/fonts"
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        ok "JetBrainsMono Nerd Font já instalada."
    else
        info "Instalando JetBrainsMono Nerd Font..."
        mkdir -p "$FONT_DIR"
        TMP_ZIP="$(mktemp /tmp/jbmono-XXXX.zip)"
        if command -v curl >/dev/null 2>&1; then
            curl -fsSL -o "$TMP_ZIP" \
                "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        elif command -v wget >/dev/null 2>&1; then
            wget -q -O "$TMP_ZIP" \
                "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        fi
        if [ -s "$TMP_ZIP" ]; then
            unzip -oq "$TMP_ZIP" -d "$FONT_DIR/JetBrainsMonoNerdFont"
            rm -f "$TMP_ZIP"
            fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
            ok "Fonte instalada em $FONT_DIR/JetBrainsMonoNerdFont"
        else
            warn "Não consegui baixar a fonte automaticamente. Baixe manualmente em:"
            warn "https://www.nerdfonts.com/font-downloads (JetBrainsMono Nerd Font)"
        fi
    fi
else
    info "Pulando instalação de fonte (--no-font)."
fi

# ---------- 3. link/copia das configs ----------
link_config() {
    local src="$1" dest="$2"

    mkdir -p "$(dirname "$dest")"

    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
            ok "$dest já aponta para o dotfiles."
            return
        fi
        local backup="${dest}.bak-${TIMESTAMP}"
        warn "Já existe $dest — fazendo backup em $backup"
        mv "$dest" "$backup"
    fi

    if [ "$NO_SYMLINK" = true ]; then
        cp -r "$src" "$dest"
        ok "Copiado: $src -> $dest"
    else
        ln -s "$src" "$dest"
        ok "Symlink criado: $dest -> $src"
    fi
}

link_config "$REPO_DIR/kitty" "$CONFIG_DIR/kitty"
link_config "$REPO_DIR/fastfetch" "$CONFIG_DIR/fastfetch"
if [ "$SKIP_EXTRAS" = false ]; then
    link_config "$REPO_DIR/starship/starship.toml" "$CONFIG_DIR/starship.toml"
fi

# ---------- 4. garantir que $HOME/.local/bin está no PATH ----------
add_path_to_rc() {
    local rc="$1"
    [ -f "$rc" ] || return
    if grep -q '\.local/bin' "$rc" 2>/dev/null; then
        ok "\$HOME/.local/bin já está no PATH em $(basename "$rc")."
    else
        {
            echo ""
            echo "# adicionado pelo install.sh dos dotfiles"
            echo 'export PATH="$HOME/.local/bin:$PATH"'
        } >> "$rc"
        ok "\$HOME/.local/bin adicionado ao PATH em $(basename "$rc")."
    fi
}
add_path_to_rc "$HOME/.bashrc"
add_path_to_rc "$HOME/.zshrc"
export PATH="$BIN_DIR:$PATH"

# ---------- 5. rodar fastfetch ao abrir o terminal ----------
add_fastfetch_to_rc() {
    local rc="$1"
    [ -f "$rc" ] || return
    if grep -q "fastfetch" "$rc" 2>/dev/null; then
        ok "fastfetch já está configurado em $(basename "$rc")."
    else
        {
            echo ""
            echo "# adicionado pelo install.sh dos dotfiles"
            echo "command -v fastfetch >/dev/null 2>&1 && fastfetch"
        } >> "$rc"
        ok "fastfetch adicionado ao $(basename "$rc")."
    fi
}

echo ""
read -rp "Quer que o fastfetch rode automaticamente ao abrir um terminal? [S/n] " resp
resp="${resp:-s}"
if [[ "$resp" =~ ^[Ss]$ ]]; then
    add_fastfetch_to_rc "$HOME/.bashrc"
    add_fastfetch_to_rc "$HOME/.zshrc"
fi

# ---------- 6. carregar aliases + starship/zoxide/fzf no shell ----------
add_shellrc_source() {
    local rc="$1"
    [ -f "$rc" ] || return
    local line="[ -f \"$CONFIG_DIR/dotfiles-shell/shellrc.sh\" ] && source \"$CONFIG_DIR/dotfiles-shell/shellrc.sh\""
    if grep -q "dotfiles-shell/shellrc.sh" "$rc" 2>/dev/null; then
        ok "shellrc já está configurado em $(basename "$rc")."
    else
        {
            echo ""
            echo "# adicionado pelo install.sh dos dotfiles (aliases + starship/eza/bat/zoxide/fzf)"
            echo "$line"
        } >> "$rc"
        ok "shellrc adicionado ao $(basename "$rc")."
    fi
}

if [ "$SKIP_EXTRAS" = false ]; then
    link_config "$REPO_DIR/shell" "$CONFIG_DIR/dotfiles-shell"
    add_shellrc_source "$HOME/.bashrc"
    add_shellrc_source "$HOME/.zshrc"
fi

echo ""
ok "Tudo pronto!"
if [ "$MODE" = "user" ]; then
    info "Tudo foi instalado em \$HOME/.local — nada fora da sua pasta pessoal foi tocado."
    info "Abra um NOVO terminal (ou rode 'source ~/.bashrc') pra o PATH atualizado valer."
fi
info "Depois disso, procure 'kitty' no menu de aplicativos ou rode 'kitty' num terminal."
info "Pra trocar a foto do fastfetch, rode: ./scripts/set-logo.sh /caminho/pra/imagem.jpg"
if [ "$SKIP_EXTRAS" = false ]; then
    info "Prompt (starship) e aliases (eza/bat/zoxide/fzf) já configurados — abra um novo shell."
fi
echo ""
