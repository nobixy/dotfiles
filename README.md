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

## Audio from Waybar

Click the audio button for headphone controls, noise control, music presets,
output selection, and app/microphone volumes. Right-click mutes; middle-click opens
the mixer. Scrolling and the volume keys use the same controls. Volume boost is
enabled by default so quiet media can be amplified up to 150%, including on the
XM5. The Volume boost menu also offers Normal mode with a 100% headphone limit.
Enabling boost leaves the current level alone; turning it off returns overdriven
headphones to 100%. This choice is remembered locally. Amplification can distort
louder recordings; a volume percentage is not a hearing-safe sound-pressure measurement.

Sony WH-1000XM5 presets live in the headphones, with no additional computer EQ:

| Preset | Clear Bass | 400 Hz | 1 kHz | 2.5 kHz | 6.3 kHz | 16 kHz |
| --- | --- | --- | --- | --- | --- | --- |
| Punch and detail | 5 | -2 | 0 | +2 | +1 | +1 |
| More bass | 8 | -2 | 0 | +2 | +1 | +1 |
| Previous sound | 8 | -1 | +1 | 0 | +3 | +5 |

These are Sony slider values, not calibrated acoustic decibels. Preset changes
keep the current noise-control mode. Choose Noise cancelling to reduce outside
noise, or Ambient Sound to hear your surroundings. Nothing changes automatically
when the menu opens or a headset connects.

`install.sh` installs the Qt runtime and calls `install-sony-audio.sh`, which
verifies the pinned [Sony Device Center v0.1.6 source](https://github.com/marconvcm/sony-device-center/tree/897022b041b7b312f6ccbd6956e5f0c6e6e76b57)
archive SHA256, builds against the installed Qt, and smoke-tests the GUI with a
simulated headset before installing under `~/.local/opt/`. The upstream prebuilt
GUI is incompatible with this Arch Qt build. Installed binaries
and Bluetooth addresses stay out of Git. To reinstall only the app, run
`./install-sony-audio.sh` after the configs have been linked. It rebuilds when Qt
or the build recipe changes and preserves the previous install on build failure. This setup is for
x86_64 Linux. The controller starts on demand, shares one connection between the
menu and GUI, and reconnects when the headphones return. It is not enabled at login.

The mentor/verifier comparison favored the Sony's onboard controls for this setup:
[EasyEffects](https://github.com/wwmm/easyeffects) remains the full-featured choice
for computer EQ, metering and limiting; [JamesDSP](https://github.com/Audio4Linux/JDSP4Linux)
is an alternative with bass and dynamics effects; [AutoEq](https://github.com/jaakkopasanen/AutoEq)
provides measured-model correction starting points. Stacking those on the current
Sony EQ was avoided. The selected tuning is a listening preference, not an objective
claim of the best possible sound.

Validation: `python3 -m unittest discover -s tests -q`, `./check.sh`, and an actual headset
check of preset/noise readback, the GUI, and shared connection recovery.
