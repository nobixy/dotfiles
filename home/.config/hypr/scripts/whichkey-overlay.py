#!/usr/bin/env python3
"""which-key for Hyprland.

An overlay that never takes keyboard focus, listing what you can press from
where you are:
  * hold ALT on its own for a moment -> everything ALT can do
  * open a leader group (ALT+F, ALT+S, ...) -> that group's keys, with live
    on/off badges and a status line where keybinds.lua asks for them
  * the ALT overview also lists the focused app's own keys (tmux and Neovim
    in kitty, Chrome, Obsidian), read from their configs where possible

Driven by ~/.config/hypr/modules/whichkey.lua through scripts/whichkey.sh;
the binds themselves come from keybinds.lua via $XDG_RUNTIME_DIR/hypr-whichkey.tsv.

Commands, one per line on $XDG_RUNTIME_DIR/hypr-whichkey.fifo, fields
separated by tabs:
    show <view> <monitor-x> <monitor-y> [<window-class> <window-title>]
                                            view = "root" or a group name
    hide
    quit

Shell checks (badges, status lines, app keys) run in threads, so the overlay
appears at once and fills them in when they answer.
"""

import fcntl
import os
import re
import shlex
import stat
import subprocess
import sys
import threading

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell  # noqa: E402

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
FIFO = os.path.join(RUNTIME, "hypr-whichkey.fifo")
LOCK = os.path.join(RUNTIME, "hypr-whichkey.lock")
DATA = os.path.join(RUNTIME, "hypr-whichkey.tsv")

COLUMNS = 4  # sections per row in the ALT overview (more when app keys join)
APP_ROWS = 7  # an app's key list wraps into a second column past this
CHECK_TIMEOUT = 2  # seconds a badge or status check may take
CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config"))

# Rice palette: Catppuccin Mocha surfaces, cyan/green accents
CSS = b"""
* { font-family: "FiraCode Nerd Font", monospace; font-size: 12px; }
window { background-color: transparent; }
.frame {
    background-color: rgba(24, 24, 37, 0.94);
    border: 2px solid #33ccff;
    border-radius: 14px;
    padding: 14px 22px 14px 22px;
}
.title  { color: #cdd6f4; font-weight: bold; font-size: 13px; }
.leader { color: #11111b; background-color: #33ccff; border-radius: 6px; padding: 0 6px; font-weight: bold; }
.header { color: #6c7086; font-weight: bold; font-size: 11px; }
.key    { color: #33ccff; font-weight: bold; }
.desc   { color: #cdd6f4; }
.group  { color: #00ff99; font-weight: bold; }
.hint   { color: #6c7086; font-size: 11px; }
.status { color: #a6adc8; }
.app    { color: #00ff99; font-weight: bold; font-size: 11px; }
.on     { color: #00ff99; }
.off    { color: #45475a; }
"""


def load(path):
    """Parse the TSV written by whichkey.lua.

    Lines: section<TAB>name | entry<TAB>keys<TAB>desc |
           group<TAB>name<TAB>title<TAB>sticky<TAB>status-command |
           item<TAB>group<TAB>key<TAB>desc<TAB>state-command
    """
    sections, groups = [], {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            kind, *fields = line.rstrip("\n").split("\t")
            fields += [""] * 4
            if kind == "section":
                sections.append((fields[0], []))
            elif kind == "entry" and sections:
                sections[-1][1].append((fields[0], fields[1], ""))
            elif kind == "group":
                groups[fields[0]] = {"title": fields[1], "sticky": fields[2] == "1",
                                     "status": fields[3], "items": []}
            elif kind == "item" and fields[0] in groups:
                groups[fields[0]]["items"].append((fields[1], fields[2], fields[3]))
    return [s for s in sections if s[1]], groups


# --- The focused app's own keys -------------------------------------------


def tmux_keys():
    """Prefix-table binds that carry a note (bind -N "...") in tmux.conf."""
    rows = []
    try:
        lines = open(os.path.join(CONFIG, "tmux/tmux.conf"), encoding="utf-8").read().splitlines()
    except OSError:
        return rows
    for line in lines:
        try:
            words = shlex.split(line, comments=True)
        except ValueError:
            continue
        if not words or words[0] not in ("bind", "bind-key"):
            continue
        note, table, i = None, "prefix", 1
        while i < len(words) and words[i].startswith("-"):
            if words[i] in ("-N", "-T"):
                if i + 1 >= len(words):
                    break
                note, table = (words[i + 1], table) if words[i] == "-N" else (note, words[i + 1])
                i += 2
            else:
                i += 1
        if note and table == "prefix" and i < len(words):
            rows.append((words[i], note, ""))
    return merge_directions(rows)


DIRECTION = re.compile(r"\b(left|down|up|right)\b")


def merge_directions(rows):
    """Neighbouring rows whose notes differ only by direction become one:
    h "Pane left", j "Pane down", ... -> "h j k l", "Pane left/down/up/right".
    Rows with a state badge stay as they are."""
    merged = []  # [keys, template, directions, state]
    for keys, note, state in rows:
        match = not state and DIRECTION.search(note)
        template = DIRECTION.sub("{}", note, count=1) if match else None
        if match and merged and merged[-1][1] == template:
            merged[-1][0].append(keys)
            merged[-1][2].append(match.group(1))
        else:
            merged.append([[keys], template or note, [match.group(1)] if match else [], state])
    return [(join_keys(keys), template.format("/".join(dirs)) if dirs else template, state)
            for keys, template, dirs, state in merged]


def join_keys(keys):
    """["⌃h", "⌃j"] -> "⌃h j": a shared modifier symbol is written once."""
    prefix = os.path.commonprefix(keys)
    if len(keys) > 1 and prefix and not prefix[-1].isalnum() and all(len(k) > len(prefix) for k in keys):
        return prefix + " ".join(k[len(prefix):] for k in keys)
    return " ".join(keys)


def nvim_groups():
    """The <leader> groups declared in the which-key.nvim spec."""
    try:
        text = open(os.path.join(CONFIG, "nvim/lua/plugins/which-key.lua"), encoding="utf-8").read()
    except OSError:
        return []
    found = re.findall(r'\{\s*"<leader>(\S+?)",\s*group\s*=\s*"([^"]+)"', text)
    return [(key, "+" + name, "") for key, name in found]


CHROME = [
    ("⌃l", "address bar", ""), ("⌃t  ⌃⇧t", "new tab / reopen closed", ""),
    ("⌃w", "close tab", ""), ("⌃⇥  ⌃⇧⇥", "next / previous tab", ""),
    ("⌃⇧a", "search open tabs", ""), ("⌃f", "find on page", ""),
]
OBSIDIAN = [
    ("⌃o", "quick switcher", ""), ("⌃p", "command palette", ""),
    ("⌃⇧f", "search the vault", ""), ("⌃e", "edit / reading view", ""),
    ("⌃n", "new note", ""), ("⌃g", "graph view", ""),
]

# window class -> [(section title, rows or a function returning rows)]
APPS = {
    "kitty": [("tmux · C-a then", tmux_keys), ("Neovim · Space then", nvim_groups)],
    "google-chrome": [("Chrome", CHROME)],
    "obsidian": [("Obsidian", OBSIDIAN)],
}


def app_sections(window_class):
    sections = []
    for title, rows in APPS.get(window_class, []):
        rows = rows() if callable(rows) else rows
        if rows:
            sections.append((title, rows))
    return sections


def run_check(command, done):
    """Run a shell check in a thread; done(ok, output) on the GTK thread."""

    def work():
        try:
            r = subprocess.run(["sh", "-c", command], stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, text=True, timeout=CHECK_TIMEOUT)
            result = (r.returncode == 0, r.stdout.strip())
        except (OSError, subprocess.TimeoutExpired):
            result = (False, "")
        GLib.idle_add(done, *result)

    threading.Thread(target=work, daemon=True).start()


def label(text, css_class, xalign=0.0):
    widget = Gtk.Label(label=text, xalign=xalign)
    widget.get_style_context().add_class(css_class)
    return widget


def key_rows(entries, check=None, max_rows=None):
    """Rows of key, description and (for entries with a state command) a
    badge that check(command, callback) fills in later. Past max_rows the
    entries wrap into a second column."""
    grid = Gtk.Grid(column_spacing=10, row_spacing=3)
    per_column = (len(entries) + 1) // 2 if max_rows and len(entries) > max_rows else len(entries)
    for i, (keys, desc, state) in enumerate(entries):
        row, col = i % per_column, 4 * (i // per_column)  # 4 grid columns per list column
        if col and row == 0:
            grid.attach(Gtk.Box(), col - 1, 0, 1, 1)  # gap between the two list columns
        grid.attach(label(keys, "key", xalign=1.0), col, row, 1, 1)
        grid.attach(label(desc, "group" if desc.startswith("+") else "desc"), col + 1, row, 1, 1)
        if state and check:
            badge = label("·", "off")
            grid.attach(badge, col + 2, row, 1, 1)
            check(state, lambda ok, _out, badge=badge: set_badge(badge, ok))
    return grid


def set_badge(badge, on):
    badge.set_text("● on" if on else "○ off")
    context = badge.get_style_context()
    context.remove_class("off" if on else "on")
    context.add_class("on" if on else "off")


def title_bar(leader, text):
    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    box.pack_start(label(leader, "leader"), False, False, 0)
    box.pack_start(label(text, "title"), False, False, 0)
    return box


class Overlay(Gtk.Window):
    def __init__(self):
        super().__init__()
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "whichkey")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(self, GtkLayerShell.KeyboardMode.NONE)
        GtkLayerShell.set_anchor(self, GtkLayerShell.Edge.BOTTOM, True)
        GtkLayerShell.set_margin(self, GtkLayerShell.Edge.BOTTOM, 48)

        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        self.frame = Gtk.Box()
        self.frame.get_style_context().add_class("frame")
        self.add(self.frame)

        self.data_mtime = None
        self.sections, self.groups = [], {}
        self.generation = 0  # bumps on every show, so late checks are dropped

    def refresh_data(self):
        try:
            mtime = os.stat(DATA).st_mtime_ns
        except OSError:
            return
        if mtime != self.data_mtime:
            self.sections, self.groups = load(DATA)
            self.data_mtime = mtime

    def check(self, command, done):
        """Run a check for the current view; drop the answer if the view changed."""
        generation = self.generation

        def answered(ok, output):
            if generation == self.generation:
                done(ok, output)
                self.resize(1, 1)  # shrink back if a line got shorter
            return False

        run_check(command, answered)

    def build(self, view, window_class):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        if view == "root":
            box.pack_start(title_bar("ALT", "+ …"), False, False, 0)
            grid = Gtk.Grid(column_spacing=34, row_spacing=14)
            columns = [(name.upper(), entries, "header") for name, entries in self.sections]
            columns += [("IN " + name.upper(), entries, "app")
                        for name, entries in app_sections(window_class)]
            per_row = max(COLUMNS, (len(columns) + 1) // 2)  # at most two rows
            for i, (name, entries, style) in enumerate(columns):
                column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                column.pack_start(label(name, style), False, False, 0)
                column.pack_start(key_rows(entries, max_rows=APP_ROWS if style == "app" else None),
                                  False, False, 0)
                grid.attach(column, i % per_row, i // per_row, 1, 1)
            box.pack_start(grid, False, False, 0)
            box.pack_start(label("release ALT to close · ALT+? searchable list", "hint"), False, False, 0)
        elif view in self.groups:
            group = self.groups[view]
            leader, _, name = group["title"].partition("  ")
            box.pack_start(title_bar(leader, name), False, False, 0)
            if group["status"]:
                status = label("…", "status")
                box.pack_start(status, False, False, 0)
                self.check(group["status"], lambda _ok, out: status.set_text(out or "(no status)"))
            box.pack_start(key_rows(merge_directions(group["items"]), self.check), False, False, 0)
            hint = "sticky: keep pressing keys · esc when done" if group["sticky"] else "esc cancel"
            box.pack_start(label(hint, "hint"), False, False, 0)
        else:
            return None
        return box

    def place_on(self, x, y):
        display = Gdk.Display.get_default()
        for i in range(display.get_n_monitors()):
            monitor = display.get_monitor(i)
            geometry = monitor.get_geometry()
            if geometry.x == x and geometry.y == y:
                GtkLayerShell.set_monitor(self, monitor)
                return

    def show_view(self, view, x, y, window_class=""):
        self.refresh_data()
        self.generation += 1
        content = self.build(view, window_class)
        if content is None:
            self.hide()
            return
        self.hide()  # remap so a new monitor and size take effect
        for child in self.frame.get_children():
            self.frame.remove(child)
        self.frame.pack_start(content, False, False, 0)
        self.place_on(x, y)
        self.resize(1, 1)
        self.show_all()

    def command(self, line):
        parts = line.split("\t")
        if parts[0] == "show" and len(parts) >= 4:
            try:
                self.show_view(parts[1], int(parts[2]), int(parts[3]), parts[4] if len(parts) > 4 else "")
            except ValueError:
                pass
        elif parts[0] == "hide":
            self.hide()
        elif parts[0] == "quit":
            Gtk.main_quit()


def open_fifo():
    try:
        os.mkfifo(FIFO, 0o600)
    except FileExistsError:
        if not stat.S_ISFIFO(os.stat(FIFO).st_mode):
            os.remove(FIFO)
            os.mkfifo(FIFO, 0o600)
    # Read+write keeps the FIFO open (no EOF) when writers come and go
    return os.open(FIFO, os.O_RDWR | os.O_NONBLOCK)


def main():
    lock = open(LOCK, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)  # already running

    overlay = Overlay()
    fd = open_fifo()
    pending = b""

    def on_input(_channel, _condition):
        nonlocal pending
        try:
            pending += os.read(fd, 4096)
        except BlockingIOError:
            return True
        *lines, pending = pending.split(b"\n")
        for line in lines:
            overlay.command(line.decode("utf-8", "replace"))
        return True

    GLib.io_add_watch(GLib.IOChannel.unix_new(fd), GLib.PRIORITY_DEFAULT, GLib.IOCondition.IN, on_input)
    Gtk.main()


if __name__ == "__main__":
    main()
