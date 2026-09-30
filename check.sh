#!/usr/bin/env bash
# Check the configs before committing: ~/dotfiles/check.sh
# Validates each config with its own program, then reports package-list drift.
# Exits non-zero if any check fails.
set -uo pipefail

DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
H=$DOTFILES/home
failed=0

pass() { printf '\033[32m  ok\033[0m  %s\n' "$1"; }
fail() { printf '\033[31mFAIL\033[0m  %s\n' "$1"; sed 's/^/      /' <<<"$2"; failed=1; }

# check <description> <command...>: passes if the command succeeds and prints
# nothing (tmux and Neovim report errors but still exit 0)
check() {
    local description=$1 out
    shift
    if out=$("$@" 2>&1) && [ -z "$out" ]; then pass "$description"; else fail "$description" "$out"; fi
}

hypr_config() {
    local out
    out=$(Hyprland --verify-config -c "$H/.config/hypr/hyprland.lua" 2>&1) || { tail -n 3 <<<"$out"; return 1; }
}
git_config() { git config -f "$H/.gitconfig" --list >/dev/null; }
tmux_config() { tmux -L dotfiles-check -f /dev/null start-server \; source-file "$H/.config/tmux/tmux.conf" \; kill-server; }
python_syntax() { python3 -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$1"; }

check "Hyprland config" hypr_config
check "zsh syntax" zsh -n "$H/.zshrc"
check "git config" git_config
check "tmux config" tmux_config
check "Neovim starts without errors" nvim --headless +qa

scripts=("$DOTFILES"/*.sh "$H"/.config/hypr/scripts/*.sh "$H"/.config/waybar/scripts/*.sh "$H"/.local/bin/eecs "$H"/.local/bin/eecs-agent)
for script in "${scripts[@]}"; do
    check "bash -n ${script#"$DOTFILES"/}" bash -n "$script"
done
for script in "$H/.config/hypr/scripts/whichkey-overlay.py" "$H/.local/bin/eecs-record"; do
    check "python syntax ${script#"$H"/}" python_syntax "$script"
done

# Lint the scripts; Neovim's Mason tools include a copy of the linter if the
# system has none
shellcheck=$(command -v shellcheck || echo ~/.local/share/nvim/mason/bin/shellcheck)
if [ -x "$shellcheck" ]; then
    check "shellcheck" "$shellcheck" --severity=warning "${scripts[@]}"
fi

# Every file in home/ should be symlinked into ~. Stow prints a LINK line for
# anything missing, and an error where a real file sits in place of a link.
links=$(stow --simulate --verbose=1 --dir="$DOTFILES" --target="$HOME" home 2>&1 | grep -v 'simulation mode')
if [ -z "$links" ]; then
    pass "configs are linked into ~"
else
    fail "configs are linked into ~   (fix: cd ~/dotfiles && stow --restow --target=\$HOME home)" "$links"
fi

# Installed packages vs packages/*.txt: a reminder to update the lists, not a failure
installed=$(pacman -Qqe | sort)
listed=$(cat "$DOTFILES"/packages/*.txt <(echo yay) | sort -u) # install.sh sets up yay itself
unlisted=$(comm -23 <(echo "$installed") <(echo "$listed"))
missing=$(comm -13 <(echo "$installed") <(echo "$listed"))
if [ -n "$unlisted$missing" ]; then
    printf '\033[33m  !!\033[0m  installed packages differ from packages/*.txt\n'
    [ -n "$unlisted" ] && sed 's/^/      installed, not in a list:  /' <<<"$unlisted"
    [ -n "$missing" ] && sed 's/^/      in a list, not installed:  /' <<<"$missing"
fi

exit "$failed"
