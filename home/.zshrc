# ~/.zshrc

# ---------- Environment & PATH ----------
typeset -U path PATH
path=($HOME/.local/bin $HOME/.cargo/bin $HOME/go/bin $path)
export PATH
export EDITOR="nvim"
export VISUAL="nvim"

# ---------- History ----------
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS EXTENDED_HISTORY
setopt HIST_VERIFY   # `!!`, `sudo !!` etc. expand onto the line for a look before running

# ---------- Options & Vi-Mode ----------
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS INTERACTIVE_COMMENTS NO_BEEP
bindkey -v
export KEYTIMEOUT=1

# Cursor shape changes for Vi-mode in Kitty (2 = block, 6 = beam)
function zle-keymap-select() {
  case $KEYMAP in
    vicmd)      print -n -- "\e[2 q" ;; # Block in normal mode
    viins|main) print -n -- "\e[6 q" ;; # Beam in insert mode
  esac
}
zle -N zle-keymap-select

function zle-line-init() {
  print -n -- "\e[6 q"
}
zle -N zle-line-init

function zle-line-finish() {
  print -n -- "\e[2 q"
}
zle -N zle-line-finish

# ---------- Completion ----------
[[ -d ~/.cache/zsh ]] || mkdir -p ~/.cache/zsh
autoload -Uz compinit
compinit -d ~/.cache/zsh/zcompdump
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/compcache
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false

# fzf keybinds first so fzf-tab keeps Tab
source <(fzf --zsh)   # Ctrl-R history, Ctrl-T files

# Explicit fzf keybinds for both viins and vicmd
bindkey -M viins '^R' fzf-history-widget
bindkey -M vicmd '^R' fzf-history-widget
bindkey -M viins '^T' fzf-file-widget
bindkey -M vicmd '^T' fzf-file-widget
bindkey -M viins -r '^[c'                # Alt-C closes windows in Hyprland,
bindkey -M vicmd -r '^[c'
bindkey -M viins '^[d' fzf-cd-widget     # so fuzzy-cd lives on Alt-D
bindkey -M vicmd '^[d' fzf-cd-widget

# Standard editing keys in viins
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^h' backward-delete-char
bindkey -M viins '^w' backward-kill-word
bindkey -M viins '^u' backward-kill-line
bindkey -M viins '^a' beginning-of-line
bindkey -M viins '^e' end-of-line

# fzf-tab: fuzzy menu for Tab completion (must load after compinit).
# It isn't packaged in the Arch repos, so install.sh clones it here.
[[ -r ~/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]] &&
  source ~/.local/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'eza -1 --color=always --icons $realpath'
zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
zstyle ':fzf-tab:complete:(-command-|-parameter-|-brace-parameter-|export|unset|expand):*' fzf-preview 'echo ${(P)word}'

# ---------- Tools ----------
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
export FZF_CTRL_T_COMMAND=$FZF_DEFAULT_COMMAND
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border
  --color=bg:-1,bg+:#313244,fg:#cdd6f4,fg+:#cdd6f4,hl:#33ccff,hl+:#33ccff
  --color=border:#45475a,header:#33ccff,info:#a6adc8,marker:#00ff99
  --color=pointer:#00ff99,prompt:#33ccff,spinner:#00ff99'

# man pages open in Neovim: gO lists the sections, K or Ctrl-] follows a reference, q quits
export MANPAGER='nvim +Man!'

command -v zoxide >/dev/null && eval "$(zoxide init zsh --cmd cd)"   # `cd foo` jumps to best match
eval "$(starship init zsh)"

# ---------- Functions ----------
# y: yazi, and the shell follows it to wherever you quit (the yazi docs'
# wrapper; named y so it doesn't hide yazi's own `ya` command)
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}

# ---------- Aliases ----------
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --git --group-directories-first'
alias la='eza -la --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias grep='grep --color=auto'
command -v bat >/dev/null && alias cat='bat --paging=never --style=plain'
alias ..='cd ..'
alias ...='cd ../..'
alias update='yay -Syu'

# Short names
alias lg='lazygit'
alias v='nvim'
alias g='git'
alias d='docker'
alias dc='docker compose'

# ---------- Keys ----------
bindkey '^[[H' beginning-of-line        # Home
bindkey '^[[F' end-of-line              # End
bindkey '^[[3~' delete-char             # Delete
bindkey '^[[1;5C' forward-word          # Ctrl-Right
bindkey '^[[1;5D' backward-word         # Ctrl-Left
# Up/Down: previous commands that start with what's typed so far
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey -M vicmd '^[[A' up-line-or-beginning-search
bindkey -M vicmd '^[[B' down-line-or-beginning-search

# ---------- Plugins (syntax highlighting must be last) ----------
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey -M viins '^ ' autosuggest-accept # Ctrl-Space accepts suggestion
bindkey '^ ' autosuggest-accept
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
