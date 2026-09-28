#!/usr/bin/env bash
# Set up this desktop on a fresh Arch Linux install. Safe to re-run: each
# step skips whatever is already done. Asks for your sudo password.
#
#   sudo pacman -S --needed git
#   git clone https://github.com/nobixy/dotfiles ~/dotfiles
#   ~/dotfiles/install.sh
set -euo pipefail

DOTFILES=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$DOTFILES"

step() { printf '\n\033[1;36m:: %s\033[0m\n' "$*"; }

if [ "$EUID" -eq 0 ]; then
    echo "Run this as your normal user, not root (it uses sudo where needed)." >&2
    exit 1
fi

step "Enabling the multilib repo (Steam and other 32-bit packages)"
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/,/^#Include/ s/^#//' /etc/pacman.conf
fi

step "Installing packages from packages/pacman.txt"
mapfile -t packages < packages/pacman.txt
sudo pacman -Syu --needed "${packages[@]}"

step "Linking configs into ~ (stow)"
# These must be real directories, or stow would link the whole folder into
# the repo and every app's files would end up in git
mkdir -p ~/.config ~/.local/share
stow --restow --target="$HOME" home

step "Installing yay and the AUR packages from packages/aur.txt"
if ! command -v yay >/dev/null; then
    tmp=$(mktemp -d)
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp"
    (cd "$tmp" && makepkg -si --noconfirm)
    rm -rf "$tmp"
fi
mapfile -t aur < packages/aur.txt
yay -S --needed "${aur[@]}"

step "zsh plugin fzf-tab (not in the Arch repos)"
fzf_tab=~/.local/share/zsh/plugins/fzf-tab
[ -d "$fzf_tab" ] || git clone --depth 1 https://github.com/Aloxaf/fzf-tab "$fzf_tab"

step "Neovim plugins, at the versions pinned in lazy-lock.json"
nvim --headless "+Lazy! restore" +qa

step "tldr pages"
tldr --update

step "Login shell and default apps"
[ "$(getent passwd "$USER" | cut -d: -f7)" = /usr/bin/zsh ] || chsh -s /usr/bin/zsh
xdg-settings set default-web-browser google-chrome.desktop
xdg-mime default org.pwmt.zathura-pdf-mupdf.desktop application/pdf

step "System services"
sudo systemctl disable getty@tty1.service   # ly takes over tty1
sudo systemctl enable ly@tty1.service bluetooth.service cups.socket tuned.service ufw.service paccache.timer
sudo ufw --force enable                      # default: block incoming, allow outgoing
sudo usermod -aG gamemode "$USER"            # lets gamemode renice games

step "Done"
cat <<'EOF'
Reboot, then log in to Hyprland from ly. After that:
  gh auth login      GitHub access for git (HTTPS)
  nvim               the first files you open install their language servers
New hardware? Check the "Machine-specific" section of README.md.
EOF
