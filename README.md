# dotfiles — kitty + fastfetch + starship

Configuração pessoal do [kitty](https://sw.kovidgoyal.net/kitty/) (terminal) e do
[fastfetch](https://github.com/fastfetch-cli/fastfetch) (system info bonito ao abrir o terminal),
com tema **Adwaita Dark**, fonte **JetBrains Mono Nerd Font**, uma foto de perfil como logo do
fastfetch, e opcionalmente um prompt ([starship](https://starship.rs/)) + CLIs modernas
(`eza`, `bat`, `zoxide`, `fzf`) já configuradas.

**Funciona mesmo sem acesso a sudo** — o instalador baixa binários prontos e instala tudo em
`~/.local`, o que cobre laboratórios de faculdade e outras máquinas onde você não é root
(testado pensando em labs como os da UFCG).

## Preview

- Terminal com transparência leve (`background_opacity 0.9`), padding generoso e cursor beam.
- Fastfetch mostrando uma imagem real como logo (em vez do logo da distro) + informações do sistema.
- Prompt do starship com segmentos coloridos (usuário, diretório, git, linguagem do projeto).
- `ls`/`ll`/`la`/`lt` via `eza` (ícones), `cat` via `bat` (syntax highlight), `cd` mais esperto
  via `zoxide`, e busca fuzzy no histórico com `Ctrl+R` via `fzf`.

## Instalação rápida

```bash
git clone https://github.com/SEU_USUARIO/dotfiles.git
cd dotfiles
chmod +x install.sh scripts/set-logo.sh
./install.sh
```

O `install.sh`:

1. **Pergunta se você tem acesso a sudo.** Se não tiver (ou passar `--user`), **nada** é
   instalado com privilégios de root: kitty, fastfetch, starship, eza, bat, zoxide e fzf são
   baixados como binários pré-compilados direto do GitHub e instalados em `~/.local/bin` /
   `~/.local/kitty.app` — só tocando na sua própria pasta. **Funciona em PCs de laboratório
   sem sudo (ex: labs da UFCG).**
2. Se você tiver sudo (ou passar `--system`), usa o gerenciador de pacotes da distro
   (`pacman`, `apt`, `dnf`, `zypper` ou `brew`); se um pacote falhar ou não existir no repositório,
   cai automaticamente para o binário pré-compilado, sem travar a instalação.
3. Pergunta se você quer instalar também **starship**, **eza**, **bat**, **zoxide** e **fzf**.
4. Baixa e instala a **JetBrainsMono Nerd Font** em `~/.local/share/fonts` (nunca precisa de sudo).
5. Faz **backup** de qualquer config existente em `~/.config/kitty`, `~/.config/fastfetch`,
   `~/.config/starship.toml` e `~/.config/dotfiles-shell` (salva como `.bak-<data>`) e cria
   **symlinks** apontando pra este repositório — então dar `git pull` no repo já atualiza sua
   config.
6. Garante que `~/.local/bin` está no seu `PATH` (adiciona ao `.bashrc`/`.zshrc` se preciso).
7. Pergunta se quer que o `fastfetch` rode automaticamente toda vez que você abrir um terminal.
8. Se você instalou os extras, adiciona uma linha no `.bashrc`/`.zshrc` que carrega
   `shell/shellrc.sh` — é ali que ficam os aliases do `eza`/`bat` e a inicialização do
   `starship`/`zoxide`/`fzf`.

### Instalando sem sudo (PC de laboratório, servidor compartilhado, etc.)

```bash
./install.sh --user
```

Isso pula completamente a pergunta sobre sudo e instala tudo em `~/.local`:

| Ferramenta | Como é instalada sem sudo |
|---|---|
| `kitty` | instalador oficial (`sw.kovidgoyal.net/kitty/installer.sh`) → `~/.local/kitty.app`, com link em `~/.local/bin` |
| `fastfetch`, `eza`, `bat`, `fzf` | binário pré-compilado baixado do GitHub Releases (`.tar.gz`) → `~/.local/bin` |
| `starship`, `zoxide` | scripts oficiais de instalação, apontados pra `~/.local/bin` |
| Nerd Font | sempre foi instalada em `~/.local/share/fonts`, com ou sem sudo |

Nada é escrito fora da sua `$HOME` — nenhum arquivo em `/usr`, `/etc` nem pacotes do sistema são
tocados. Um bônus: o `kitty` ainda aparece no menu de aplicativos, porque o `.desktop` file é
copiado pra `~/.local/share/applications`, que também não precisa de root.

### Flags opcionais

```bash
./install.sh --user          # instala tudo em ~/.local, sem sudo (ideal pra labs)
./install.sh --system        # usa o gerenciador de pacotes do sistema (precisa de sudo)
./install.sh --no-font       # não baixa a Nerd Font
./install.sh --no-extras     # não instala/configura starship, eza, bat, zoxide, fzf
./install.sh --copy          # copia os arquivos em vez de criar symlink
```

Sem nenhuma dessas duas primeiras flags, o script pergunta interativamente se você tem sudo.

## Trocar a foto do fastfetch

```bash
./scripts/set-logo.sh /caminho/para/sua-foto.jpg
```

Isso substitui `~/.config/fastfetch/logo.jpg`. Se preferir fazer manualmente, é só sobrescrever
esse arquivo (mantendo o mesmo nome) ou editar o campo `logo.source` em
`fastfetch/config.jsonc`.

## Estrutura

```
dotfiles/
├── install.sh              # instalador
├── scripts/
│   └── set-logo.sh         # troca a foto do fastfetch
├── kitty/
│   ├── kitty.conf           # config principal do kitty
│   └── current-theme.conf   # tema Adwaita Dark
├── fastfetch/
│   ├── config.jsonc         # layout/módulos do fastfetch
│   └── logo.jpg             # imagem usada como logo
├── starship/
│   └── starship.toml        # prompt (segmentos com paleta Adwaita Dark)
└── shell/
    └── shellrc.sh           # aliases (eza/bat) + init do starship/zoxide/fzf
```

## Customizando

- **Cores do terminal**: edite `kitty/current-theme.conf`, ou troque de tema com
  `kitten themes` (kitty já vem com um seletor de temas embutido).
- **Fonte**: mude `font_family` em `kitty/kitty.conf` (por padrão `Jetbrains Mono Nerd Font`).
- **Transparência**: `background_opacity` em `kitty/kitty.conf` (0.0 a 1.0).
- **Módulos do fastfetch** (o que aparece: OS, kernel, uptime, etc.): edite a lista `modules`
  em `fastfetch/config.jsonc`. Referência completa de módulos:
  https://github.com/fastfetch-cli/fastfetch/wiki/Configuration

## Publicando no GitHub

```bash
cd dotfiles
git init
git add .
git commit -m "dotfiles: kitty + fastfetch"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/dotfiles.git
git push -u origin main
```

Depois disso, qualquer pessoa pode instalar sua config com os três comandos da seção
"Instalação rápida" lá em cima.

## Ferramentas extras incluídas

O `install.sh` oferece instalar e já deixar configurado:

| Ferramenta | O que faz | Onde fica configurado |
|---|---|---|
| [`starship`](https://starship.rs/) | Prompt de shell rápido, com segmentos de usuário/diretório/git/linguagem | `starship/starship.toml` |
| [`eza`](https://github.com/eza-community/eza) | Substitui o `ls` (ícones, cores, árvore) — aliases `ls`, `ll`, `la`, `lt` | `shell/shellrc.sh` |
| [`bat`](https://github.com/sharkdp/bat) | Substitui o `cat` com syntax highlighting | `shell/shellrc.sh` |
| [`zoxide`](https://github.com/ajeetdsouza/zoxide) | `cd` mais esperto — aprende os diretórios mais usados (alias `cd`) | `shell/shellrc.sh` |
| [`fzf`](https://github.com/junegunn/fzf) | Busca fuzzy (`Ctrl+R` no histórico, `Ctrl+T` pra arquivos) | `shell/shellrc.sh` |

Pra pular tudo isso na instalação, use `./install.sh --no-extras` ou responda `n` quando o
instalador perguntar. Pra instalar depois, é só rodar `./install.sh` de novo.

Bash e zsh já são detectados automaticamente pelo `shell/shellrc.sh` — fish não é suportado
ainda, mas dá pra adaptar o `shellrc.sh` fácil se você usar fish.

## Licença

MIT — use, modifique e distribua à vontade.
# ConfiguracaoTerminal
