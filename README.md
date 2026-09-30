# dotfiles

My Arch Linux + Hyprland desktop. It's keyboard-driven, with Neovim-style keys everywhere
(ALT is the desktop's leader key, as Space is Neovim's), and themed Catppuccin Mocha with
cyan/green accents.

## New machine

1. Install Arch with `archinstall`. This machine uses: the *minimal* profile, btrfs with
   snapper snapshots, Limine, zram swap, PipeWire audio, NVIDIA open drivers, and the
   *copy ISO network configuration* option. [`packages/system.txt`](packages/system.txt)
   lists the kernel, boot and driver packages that produced.
2. Log in, then:
   ```sh
   sudo pacman -S --needed git
   git clone https://github.com/nobixy/dotfiles ~/dotfiles
   ~/dotfiles/install.sh
   ```
3. Reboot, log in to Hyprland from ly, and run `gh auth login`.

`install.sh` is safe to re-run. It installs the packages, links the configs, sets up yay
and the AUR packages, the zsh plugin, Neovim plugins, the login shell, default apps and
services.

## Everyday use

The configs in `~` are symlinks into `home/`, so edit them where they are (`nvim ~/.zshrc`)
and the change is already in the repo. Most are whole-folder links
(`~/.config/nvim` → `~/dotfiles/home/.config/nvim`), so a file an app creates in one of
those folders shows up in `git status` too.

```sh
cd ~/dotfiles
./check.sh                                  # validate every config
git add -A && git commit -m "…" && git push
```

- **Add a config:** move it into `home/` at the path it has under `~`, then relink:
  `mv ~/.config/foo ~/dotfiles/home/.config/ && cd ~/dotfiles && stow --restow --target=$HOME home`
- **Installed or removed a package?** `check.sh` lists the drift. Add or remove the name in
  `packages/pacman.txt` (official repos) or `packages/aur.txt` (AUR).
- **Never commit secrets.** Tokens, keys and passwords stay out of the repo. Examples:
  `~/.ssh/`, `~/.config/gh/hosts.yml`, `~/.config/opencode/service.json`, `~/token.json`.

## What's here

| Path | What it is |
| --- | --- |
| `install.sh` | Set up a fresh install (re-runnable) |
| `check.sh` | Validate the configs, show package drift |
| `packages/` | `pacman.txt` repo packages, `aur.txt` AUR packages, `system.txt` this machine's archinstall picks (not installed by the script) |
| `home/.zshrc` | zsh: vi mode, fzf (Ctrl-R, Ctrl-T, Alt-D), fzf-tab, zoxide (`cd` jumps), starship |
| `home/.gitconfig` | git: identity, GitHub CLI auth, delta diffs, defaults |
| `home/.config/hypr/` | Hyprland (Lua): ALT leader groups, which-key overlay, startup layout, lock, idle, wallpaper |
| `waybar/`, `rofi/`, `dunst/` | Bar, launcher and menus, notifications |
| `kitty/`, `tmux/`, `starship.toml` | Terminal, multiplexer (prefix Ctrl-a), prompt |
| `nvim/` | Neovim on lazy.nvim. Languages live in `lua/config/languages.lua` |
| `yazi/`, `lazygit/`, `btop/`, `bat/`, `zathura/` | File manager, git UI, system monitor, `cat`, PDF viewer |
| `gtk-3.0/`, `gtk-4.0/`, `qt6ct/`, `kdeglobals`, `.local/share/color-schemes/` | Dark theme for GTK, Qt and KDE apps |
| `pacman/makepkg.conf` | Parallel AUR builds, no `-debug` packages |

## Machine-specific

On different hardware, check these:

- `hypr/modules/monitors.lua`: monitor names, modes, positions and which workspaces live on
  each (`hyprctl monitors` lists the names). Any other monitor still works, placed to the right.
- `waybar/config.jsonc`: the side bar's `output` list. The main bar shows on every monitor
  not in that list.
- `hypr/modules/env.lua`: the NVIDIA variables switch on by themselves when the NVIDIA
  driver is loaded.

## Keys

- **Desktop:** hold ALT for the which-key overlay, or press ALT+? for a searchable list.
  The overlay also lists the focused app's own keys (tmux and Neovim in kitty, Chrome,
  Obsidian). ALT+F, S, B, T, R and I open leader groups (find, split, buffer, toggle,
  rename/restart, study), like `<leader>f` etc. in Neovim; groups can nest (ALT+I, o) and
  show live on/off badges (ALT+T). ALT+M is window mode, a sticky group: h/j/k/l, H/J/K/L
  and ⌃h/j/k/l work without ALT until you press esc.
- **Study:** ALT+I (or `<leader>i` in Neovim) opens today's log, the current block note
  and the Study Bench, and runs the study agents. `eecs --help` covers the command line;
  its settings live in `~/.config/eecs/config.json`, outside this repo.
- **Neovim:** press Space and wait for which-key.
- **Shell:** `y` opens yazi and follows it to where you quit; `man` pages open in Neovim.

Further reading: `man stow`, and [The Missing Semester, lecture 5](https://missing.csail.mit.edu/2020/command-line/)
(dotfiles and the command-line environment).
