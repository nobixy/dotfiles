#!/usr/bin/env python3
"""which-key for Hyprland.

An overlay that never takes keyboard focus, listing what you can press from
where you are:
  * hold ALT on its own for a moment -> everything ALT can do
  * open a leader group (ALT+F, ALT+S, ...) -> that group's keys

Driven by ~/.config/hypr/modules/whichkey.lua through scripts/whichkey.sh;
the binds themselves come from keybinds.lua via $XDG_RUNTIME_DIR/hypr-whichkey.tsv.

Commands, one per line on $XDG_RUNTIME_DIR/hypr-whichkey.fifo:
    show <view> <monitor-x> <monitor-y>     view = "root" or a group name
    hide
    quit
"""

import fcntl
import os
import stat
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, GLib, Gtk, GtkLayerShell  # noqa: E402

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/tmp")
FIFO = os.path.join(RUNTIME, "hypr-whichkey.fifo")
LOCK = os.path.join(RUNTIME, "hypr-whichkey.lock")
DATA = os.path.join(RUNTIME, "hypr-whichkey.tsv")

COLUMNS = 4  # sections per row in the ALT overview

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
"""


def load(path):
    """Parse the TSV written by whichkey.lua.

    Lines: section<TAB>name | entry<TAB>keys<TAB>desc |
           group<TAB>name<TAB>title | item<TAB>group<TAB>key<TAB>desc
    """
    sections, groups = [], {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            kind, *fields = line.rstrip("\n").split("\t")
            if kind == "section":
                sections.append((fields[0], []))
            elif kind == "entry" and sections:
                sections[-1][1].append((fields[0], fields[1]))
            elif kind == "group":
                groups[fields[0]] = (fields[1], [])
            elif kind == "item" and fields[0] in groups:
                groups[fields[0]][1].append((fields[1], fields[2]))
    return [s for s in sections if s[1]], groups


def label(text, css_class, xalign=0.0):
    widget = Gtk.Label(label=text, xalign=xalign)
    widget.get_style_context().add_class(css_class)
    return widget


def key_rows(entries):
    grid = Gtk.Grid(column_spacing=10, row_spacing=3)
    for row, (keys, desc) in enumerate(entries):
        grid.attach(label(keys, "key", xalign=1.0), 0, row, 1, 1)
        grid.attach(label(desc, "group" if desc.startswith("+") else "desc"), 1, row, 1, 1)
    return grid


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

    def refresh_data(self):
        try:
            mtime = os.stat(DATA).st_mtime_ns
        except OSError:
            return
        if mtime != self.data_mtime:
            self.sections, self.groups = load(DATA)
            self.data_mtime = mtime

    def build(self, view):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        if view == "root":
            box.pack_start(title_bar("ALT", "+ …"), False, False, 0)
            grid = Gtk.Grid(column_spacing=34, row_spacing=14)
            for i, (name, entries) in enumerate(self.sections):
                column = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                column.pack_start(label(name.upper(), "header"), False, False, 0)
                column.pack_start(key_rows(entries), False, False, 0)
                grid.attach(column, i % COLUMNS, i // COLUMNS, 1, 1)
            box.pack_start(grid, False, False, 0)
            box.pack_start(label("release ALT to close · ALT+? searchable list", "hint"), False, False, 0)
        elif view in self.groups:
            title, items = self.groups[view]
            leader, _, name = title.partition("  ")
            box.pack_start(title_bar(leader, name), False, False, 0)
            box.pack_start(key_rows(items), False, False, 0)
            box.pack_start(label("esc cancel", "hint"), False, False, 0)
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

    def show_view(self, view, x, y):
        self.refresh_data()
        content = self.build(view)
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
        parts = line.split()
        if not parts:
            return
        if parts[0] == "show" and len(parts) == 4:
            try:
                self.show_view(parts[1], int(parts[2]), int(parts[3]))
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
