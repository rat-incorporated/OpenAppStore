#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Repo Forge
==========

A small Tkinter GUI for creating and editing the JSON repository index that the
OpenAppStore (Flutter/Android) app reads.

Each repository is a single JSON document that describes the repo and lists the
apps it contains, along with every downloadable release (APK) of those apps.

Usage
-----
    python repo_forge.py                # start with an empty repository
    python repo_forge.py repo.json      # open an existing repository

The tool has no third-party dependencies; it only needs a Python 3.9+ install
that ships Tkinter (the standard python.org Windows installer does).
"""

from __future__ import annotations

import copy
import datetime as dt
import hashlib
import json
import os
import sys
import urllib.request
import webbrowser

import tkinter as tk
from tkinter import filedialog, messagebox, ttk

# --------------------------------------------------------------------------- #
# Schema constants
# --------------------------------------------------------------------------- #

FORMAT_VERSION = 1
DEFAULT_INDEX_NAME = "repo.json"

CATEGORIES = [
    "Tools", "Productivity", "Games", "Education", "Multimedia",
    "Internet", "Development", "Security", "Privacy", "System",
    "Graphics", "Health", "Finance", "Communication", "Utilities", "Other",
]

CHANNELS = ["stable", "beta", "alpha"]

# key -> (label, placeholder)
DETAIL_FIELDS = [
    ("id",           "Package ID *",     "com.example.myapp"),
    ("name",         "App name *",       "My App"),
    ("summary",      "Summary",          "One line that shows in the list"),
    ("developer",    "Developer",        "Jane Doe"),
    ("license",      "License",          "MIT"),
    ("icon",         "Icon URL",         "https://example.com/icon.png"),
    ("categories",   "Categories",       "Tools, Privacy"),
    ("tags",         "Tags",             "utility, offline"),
]

LINK_FIELDS = [
    ("homepage",     "Homepage",         "https://example.com"),
    ("sourceCode",   "Source code",      "https://github.com/me/app"),
    ("issueTracker", "Issue tracker",    "https://github.com/me/app/issues"),
    ("donate",       "Donate",           "https://example.com/donate"),
]

RELEASE_FIELDS = [
    ("versionName",     "Version name",   "1.0.0"),
    ("versionCode",     "Version code",   "1"),
    ("channel",         "Channel",        "stable"),
    ("url",             "APK URL",        "https://example.com/app-1.0.0.apk"),
    ("size",            "Size (bytes)",   "0"),
    ("sha256",          "SHA-256",        ""),
    ("minSdkVersion",   "Min SDK",        "21"),
    ("targetSdkVersion", "Target SDK",    "34"),
    ("added",           "Added (date)",   ""),
]

REPO_FIELDS = [
    ("name",        "Repository name *", "My Repo"),
    ("homepage",    "Homepage",          "https://example.com"),
    ("description", "Description",       "A short description of this repository"),
    ("mirrors",     "Mirrors",           "https://mirror.example.com/repo.json"),
]


def _now_iso() -> str:
    return dt.datetime.now().replace(microsecond=0).isoformat()


def _csv_to_list(text: str) -> list[str]:
    return [p.strip() for p in text.split(",") if p.strip()]


def _list_to_csv(value) -> str:
    if not value:
        return ""
    return ", ".join(str(v) for v in value)


def _lines_to_list(text: str) -> list[str]:
    return [ln.strip() for ln in text.splitlines() if ln.strip()]


def _sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def new_repo() -> dict:
    return {
        "formatVersion": FORMAT_VERSION,
        "name": "My Repo",
        "description": "",
        "homepage": "",
        "mirrors": [],
        "lastUpdated": _now_iso(),
        "apps": [],
    }


def new_app() -> dict:
    return {
        "id": "",
        "name": "",
        "summary": "",
        "description": "",
        "developer": "",
        "license": "",
        "categories": [],
        "tags": [],
        "icon": "",
        "screenshots": [],
        "homepage": "",
        "sourceCode": "",
        "issueTracker": "",
        "donate": "",
        "releases": [],
    }


def new_release() -> dict:
    return {
        "versionName": "",
        "versionCode": 1,
        "channel": "stable",
        "url": "",
        "size": 0,
        "sha256": "",
        "minSdkVersion": 21,
        "targetSdkVersion": 34,
        "added": dt.date.today().isoformat(),
        "changelog": "",
    }


# Canonical key order so saved files stay tidy and diff-friendly.
REPO_KEY_ORDER = ["formatVersion", "name", "description", "homepage", "mirrors",
                  "lastUpdated", "apps"]
APP_KEY_ORDER = ["id", "name", "summary", "description", "developer", "license",
                 "categories", "tags", "icon", "screenshots", "homepage",
                 "sourceCode", "issueTracker", "donate", "releases"]
RELEASE_KEY_ORDER = ["versionName", "versionCode", "channel", "url", "size",
                     "sha256", "minSdkVersion", "targetSdkVersion", "added",
                     "changelog"]


def _ordered(src: dict, order: list[str]) -> dict:
    out = {k: src.get(k) for k in order if k in src}
    for k, v in src.items():
        if k not in order:
            out[k] = v
    return out


def normalize_repo(repo: dict) -> dict:
    """Return a copy of *repo* with every object in canonical key order."""
    repo = dict(repo)
    repo["formatVersion"] = FORMAT_VERSION
    repo["apps"] = [
        _ordered(
            {**a, "releases": [_ordered(r, RELEASE_KEY_ORDER) for r in a.get("releases", [])]},
            APP_KEY_ORDER,
        )
        for a in repo.get("apps", [])
    ]
    return _ordered(repo, REPO_KEY_ORDER)


def latest_release(app: dict) -> dict | None:
    releases = app.get("releases") or []
    if not releases:
        return None
    return max(releases, key=lambda r: int(r.get("versionCode") or 0))


# --------------------------------------------------------------------------- #
# Application
# --------------------------------------------------------------------------- #

class RepoForge(tk.Tk):
    def __init__(self, path: str | None = None):
        super().__init__()
        self.title("Repo Forge — OpenAppStore repository editor")
        self.geometry("1120x760")
        self.minsize(960, 640)

        self.repo = new_repo()
        self.path: str | None = None
        self.current_index: int | None = None
        self.dirty = False
        self._loading = False
        self._release_row: str | None = None

        self._entries: dict[str, ttk.Entry] = {}
        self._texts: dict[str, tk.Text] = {}
        self._release_entries: dict[str, ttk.Entry] = {}

        self._build_menu()
        self._build_layout()
        self._bind_shortcuts()

        if path:
            self._load_path(path)
        else:
            self._refresh_repo_form()
            self._refresh_app_list()

        self.protocol("WM_DELETE_WINDOW", self._on_close)

    # -- chrome ------------------------------------------------------------ #

    def _build_menu(self) -> None:
        menubar = tk.Menu(self)

        filemenu = tk.Menu(menubar, tearoff=0)
        filemenu.add_command(label="New repository", accelerator="Ctrl+N", command=self.new_file)
        filemenu.add_command(label="Open…", accelerator="Ctrl+O", command=self.open_file)
        filemenu.add_command(label="Fetch from URL…", command=self.fetch_url)
        filemenu.add_separator()
        filemenu.add_command(label="Save", accelerator="Ctrl+S", command=self.save_file)
        filemenu.add_command(label="Save as…", accelerator="Ctrl+Shift+S", command=self.save_file_as)
        filemenu.add_separator()
        filemenu.add_command(label="Export JSON preview…", command=self.export_preview)
        filemenu.add_separator()
        filemenu.add_command(label="Quit", command=self._on_close)
        menubar.add_cascade(label="File", menu=filemenu)

        appmenu = tk.Menu(menubar, tearoff=0)
        appmenu.add_command(label="New app", accelerator="Ctrl+M", command=self.add_app)
        appmenu.add_command(label="Duplicate app", command=self.duplicate_app)
        appmenu.add_command(label="Delete app", command=self.delete_app)
        appmenu.add_separator()
        appmenu.add_command(label="Move up", command=lambda: self.move_app(-1))
        appmenu.add_command(label="Move down", command=lambda: self.move_app(1))
        appmenu.add_separator()
        appmenu.add_command(label="Validate repository", command=self.validate_repo)
        menubar.add_cascade(label="App", menu=appmenu)

        helpmenu = tk.Menu(menubar, tearoff=0)
        helpmenu.add_command(label="About", command=self.show_about)
        menubar.add_cascade(label="Help", menu=helpmenu)

        self.config(menu=menubar)

    def _build_layout(self) -> None:
        toolbar = ttk.Frame(self, padding=(8, 6))
        toolbar.pack(side=tk.TOP, fill=tk.X)
        ttk.Button(toolbar, text="New", command=self.new_file).pack(side=tk.LEFT)
        ttk.Button(toolbar, text="Open", command=self.open_file).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(toolbar, text="Fetch URL", command=self.fetch_url).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(toolbar, text="Save", command=self.save_file).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(toolbar, text="Save as", command=self.save_file_as).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Separator(toolbar, orient=tk.VERTICAL).pack(side=tk.LEFT, fill=tk.Y, padx=10)
        ttk.Button(toolbar, text="Validate", command=self.validate_repo).pack(side=tk.LEFT)
        self.status = ttk.Label(toolbar, text="Ready", anchor=tk.E)
        self.status.pack(side=tk.RIGHT)

        main = ttk.Panedwindow(self, orient=tk.HORIZONTAL)
        main.pack(fill=tk.BOTH, expand=True, padx=8, pady=(0, 8))

        # ---- left: repository + app list -------------------------------- #
        left = ttk.Frame(main, padding=0)
        main.add(left, weight=1)

        repo_box = ttk.LabelFrame(left, text="Repository", padding=8)
        repo_box.pack(fill=tk.X)
        for row, (key, label, _ph) in enumerate(REPO_FIELDS):
            ttk.Label(repo_box, text=label).grid(row=row, column=0, sticky=tk.W, pady=2)
            if key == "description":
                ent = ttk.Entry(repo_box)
                ent.grid(row=row, column=1, sticky=tk.EW, padx=(8, 0), pady=2)
            else:
                ent = ttk.Entry(repo_box)
                ent.grid(row=row, column=1, sticky=tk.EW, padx=(8, 0), pady=2)
            ent.bind("<KeyRelease>", lambda _e: self._mark_dirty())
            self._entries["repo." + key] = ent
        repo_box.columnconfigure(1, weight=1)

        list_head = ttk.Frame(left)
        list_head.pack(fill=tk.X, pady=(10, 4))
        ttk.Label(list_head, text="Apps", font=("", 10, "bold")).pack(side=tk.LEFT)
        self.app_count = ttk.Label(list_head, text="(0)")
        self.app_count.pack(side=tk.LEFT, padx=(6, 0))

        search_row = ttk.Frame(left)
        search_row.pack(fill=tk.X)
        ttk.Label(search_row, text="Filter:").pack(side=tk.LEFT)
        self.search_var = tk.StringVar()
        self.search_var.trace_add("write", lambda *_: self._refresh_app_list())
        ttk.Entry(search_row, textvariable=self.search_var).pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(6, 0))

        tree_wrap = ttk.Frame(left)
        tree_wrap.pack(fill=tk.BOTH, expand=True, pady=(6, 0))
        self.app_tree = ttk.Treeview(tree_wrap, columns=("name", "id", "ver"),
                                     show="headings", selectmode="browse")
        self.app_tree.heading("name", text="Name")
        self.app_tree.heading("id", text="Package ID")
        self.app_tree.heading("ver", text="Latest")
        self.app_tree.column("name", width=150, anchor=tk.W)
        self.app_tree.column("id", width=170, anchor=tk.W)
        self.app_tree.column("ver", width=70, anchor=tk.W, stretch=False)
        vsb = ttk.Scrollbar(tree_wrap, orient=tk.VERTICAL, command=self.app_tree.yview)
        self.app_tree.configure(yscrollcommand=vsb.set)
        self.app_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        vsb.pack(side=tk.RIGHT, fill=tk.Y)
        self.app_tree.bind("<<TreeviewSelect>>", self._on_app_select)

        btn_row = ttk.Frame(left)
        btn_row.pack(fill=tk.X, pady=(6, 0))
        ttk.Button(btn_row, text="+ New", command=self.add_app).pack(side=tk.LEFT)
        ttk.Button(btn_row, text="Duplicate", command=self.duplicate_app).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(btn_row, text="Delete", command=self.delete_app).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(btn_row, text="↑", width=3, command=lambda: self.move_app(-1)).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(btn_row, text="↓", width=3, command=lambda: self.move_app(1)).pack(side=tk.LEFT)

        # ---- right: notebook -------------------------------------------- #
        right = ttk.Frame(main)
        main.add(right, weight=2)

        self.notebook = ttk.Notebook(right)
        self.notebook.pack(fill=tk.BOTH, expand=True)

        self._build_details_tab()
        self._build_description_tab()
        self._build_links_tab()
        self._build_releases_tab()
        self._build_preview_tab()

    # -- tabs -------------------------------------------------------------- #

    def _build_details_tab(self) -> None:
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Details")
        for row, (key, label, placeholder) in enumerate(DETAIL_FIELDS):
            ttk.Label(tab, text=label).grid(row=row, column=0, sticky=tk.W, pady=4)
            ent = ttk.Entry(tab)
            ent.grid(row=row, column=1, sticky=tk.EW, padx=(10, 0), pady=4)
            self._add_placeholder(ent, placeholder)
            ent.bind("<KeyRelease>", lambda _e: self._mark_dirty())
            self._entries[key] = ent
        hint = ttk.Label(
            tab,
            text="Package ID is the unique Android applicationId (e.g. com.example.app).",
            foreground="#666",
        )
        hint.grid(row=len(DETAIL_FIELDS) + 1, column=0, columnspan=2, sticky=tk.W, pady=(14, 0))
        tab.columnconfigure(1, weight=1)

    def _build_description_tab(self) -> None:
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Description")

        ttk.Label(tab, text="Full description (Markdown)").pack(anchor=tk.W)
        self._texts["description"] = self._make_text(tab, height=12)

        ttk.Label(tab, text="Screenshots (one URL per line)").pack(anchor=tk.W, pady=(12, 0))
        self._texts["screenshots"] = self._make_text(tab, height=6)
        tab.columnconfigure(0, weight=1)

    def _build_links_tab(self) -> None:
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Links")
        for row, (key, label, placeholder) in enumerate(LINK_FIELDS):
            ttk.Label(tab, text=label).grid(row=row, column=0, sticky=tk.W, pady=4)
            ent = ttk.Entry(tab)
            ent.grid(row=row, column=1, sticky=tk.EW, padx=(10, 0), pady=4)
            self._add_placeholder(ent, placeholder)
            ent.bind("<KeyRelease>", lambda _e: self._mark_dirty())
            self._entries[key] = ent
        tab.columnconfigure(1, weight=1)

    def _build_releases_tab(self) -> None:
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="Releases")

        ttk.Label(tab, text="Releases for the selected app (highest version code wins).").pack(anchor=tk.W)

        tree_wrap = ttk.Frame(tab)
        tree_wrap.pack(fill=tk.BOTH, expand=True, pady=(6, 8))
        cols = ("versionName", "versionCode", "channel", "size", "url")
        self.rel_tree = ttk.Treeview(tree_wrap, columns=cols, show="headings", selectmode="browse", height=6)
        for c, w in (("versionName", 90), ("versionCode", 90), ("channel", 70),
                     ("size", 90), ("url", 320)):
            self.rel_tree.heading(c, text=c)
            self.rel_tree.column(c, width=w, anchor=tk.W,
                                 stretch=(c == "url"))
        rvsb = ttk.Scrollbar(tree_wrap, orient=tk.VERTICAL, command=self.rel_tree.yview)
        self.rel_tree.configure(yscrollcommand=rvsb.set)
        self.rel_tree.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        rvsb.pack(side=tk.RIGHT, fill=tk.Y)
        self.rel_tree.bind("<<TreeviewSelect>>", self._on_release_select)

        form = ttk.LabelFrame(tab, text="Release fields", padding=10)
        form.pack(fill=tk.X)
        for i, (key, label, placeholder) in enumerate(RELEASE_FIELDS):
            r, c = divmod(i, 2)
            ttk.Label(form, text=label).grid(row=r, column=c * 2, sticky=tk.W, pady=3, padx=(0, 4))
            ent = ttk.Entry(form)
            ent.grid(row=r, column=c * 2 + 1, sticky=tk.EW, padx=(0, 14), pady=3)
            self._add_placeholder(ent, placeholder)
            self._release_entries[key] = ent
        form.columnconfigure(1, weight=1)
        form.columnconfigure(3, weight=1)

        ttk.Label(tab, text="Changelog").pack(anchor=tk.W, pady=(10, 0))
        self._texts["changelog"] = self._make_text(tab, height=4)

        row = ttk.Frame(tab)
        row.pack(fill=tk.X, pady=(8, 0))
        ttk.Button(row, text="Add release", command=self.add_release).pack(side=tk.LEFT)
        ttk.Button(row, text="Update release", command=self.update_release).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(row, text="Remove release", command=self.remove_release).pack(side=tk.LEFT, padx=(6, 0))
        ttk.Button(row, text="Pick APK file…", command=self.pick_apk).pack(side=tk.LEFT, padx=(16, 0))

    def _build_preview_tab(self) -> None:
        tab = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(tab, text="JSON preview")
        row = ttk.Frame(tab)
        row.pack(fill=tk.X)
        ttk.Button(row, text="Refresh preview", command=self.refresh_preview).pack(side=tk.LEFT)
        ttk.Button(row, text="Copy to clipboard", command=self.copy_preview).pack(side=tk.LEFT, padx=(6, 0))
        self.preview = self._make_text(tab, height=24, monospace=True)

    # -- widget helpers ---------------------------------------------------- #

    def _make_text(self, parent, height: int, monospace: bool = False) -> tk.Text:
        wrap = ttk.Frame(parent)
        wrap.pack(fill=tk.BOTH, expand=True, pady=(2, 0))
        font = ("Consolas", 10) if monospace else ("", 10)
        text = tk.Text(wrap, height=height, wrap=tk.WORD, font=font,
                       undo=True, relief=tk.FLAT, borderwidth=1,
                       highlightthickness=1, highlightbackground="#c8c8c8")
        sb = ttk.Scrollbar(wrap, orient=tk.VERTICAL, command=text.yview)
        text.configure(yscrollcommand=sb.set)
        text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        sb.pack(side=tk.RIGHT, fill=tk.Y)
        text.bind("<KeyRelease>", lambda _e: self._mark_dirty())
        return text

    def _add_placeholder(self, entry: ttk.Entry, placeholder: str) -> None:
        """Show greyed-out placeholder text that is never saved."""
        if not placeholder:
            return
        entry._placeholder = placeholder  # type: ignore[attr-defined]

        def show() -> None:
            if not entry.get():
                entry.insert(0, placeholder)
                entry.configure(foreground="#888")
                entry._is_placeholder = True  # type: ignore[attr-defined]

        def hide(_e=None) -> None:
            if getattr(entry, "_is_placeholder", False):
                entry.delete(0, tk.END)
                entry.configure(foreground="")
                entry._is_placeholder = False  # type: ignore[attr-defined]

        entry.bind("<FocusIn>", hide, add="+")
        entry.bind("<FocusOut>", lambda _e: show(), add="+")
        show()

    def _entry_value(self, entry: ttk.Entry) -> str:
        text = entry.get().strip()
        placeholder = getattr(entry, "_placeholder", "")
        # The placeholder is only "empty" while it still holds placeholder text.
        if getattr(entry, "_is_placeholder", False) and text == placeholder:
            return ""
        return text

    def _set_entry(self, entry: ttk.Entry, value: str) -> None:
        entry.delete(0, tk.END)
        entry.configure(foreground="")
        entry._is_placeholder = False  # type: ignore[attr-defined]
        if value:
            entry.insert(0, str(value))
        elif getattr(entry, "_placeholder", ""):
            entry.insert(0, entry._placeholder)  # type: ignore[attr-defined]
            entry.configure(foreground="#888")
            entry._is_placeholder = True  # type: ignore[attr-defined]

    def _text_value(self, key: str) -> str:
        return self._texts[key].get("1.0", "end-1c").strip()

    def _set_text(self, key: str, value: str) -> None:
        self._texts[key].delete("1.0", tk.END)
        self._texts[key].insert("1.0", value or "")

    # -- shortcuts --------------------------------------------------------- #

    def _bind_shortcuts(self) -> None:
        self.bind_all("<Control-n>", lambda _e: self.new_file())
        self.bind_all("<Control-o>", lambda _e: self.open_file())
        self.bind_all("<Control-s>", lambda _e: self.save_file())
        self.bind_all("<Control-S>", lambda _e: self.save_file_as())
        self.bind_all("<Control-m>", lambda _e: self.add_app())

    # -- status / dirty ---------------------------------------------------- #

    def _set_status(self, text: str) -> None:
        self.status.configure(text=text)

    def _mark_dirty(self) -> None:
        if self._loading:
            return
        if not self.dirty:
            self.dirty = True
            self._update_title()

    def _update_title(self) -> None:
        name = os.path.basename(self.path) if self.path else "Untitled"
        star = " *" if self.dirty else ""
        self.title(f"Repo Forge — {name}{star}")

    def _confirm_discard(self) -> bool:
        if not self.dirty:
            return True
        ans = messagebox.askyesnocancel(
            "Unsaved changes",
            "Save changes before continuing?",
            parent=self,
        )
        if ans is None:
            return False
        if ans:
            return self.save_file()
        return True

    # -- repo form --------------------------------------------------------- #

    def _refresh_repo_form(self) -> None:
        self._loading = True
        try:
            for key, _label, _ph in REPO_FIELDS:
                value = self.repo.get(key, "")
                if key == "mirrors":
                    value = _list_to_csv(value)
                self._set_entry(self._entries["repo." + key], value)
        finally:
            self._loading = False

    def _collect_repo_form(self) -> None:
        for key, _label, _ph in REPO_FIELDS:
            value = self._entry_value(self._entries["repo." + key])
            if key == "mirrors":
                self.repo[key] = _csv_to_list(value)
            else:
                self.repo[key] = value

    # -- app list ---------------------------------------------------------- #

    def _refresh_app_list(self, select: int | None = None) -> None:
        if select is None:
            select = self.current_index
        query = self.search_var.get().strip().lower()
        self.app_tree.delete(*self.app_tree.get_children())
        self._tree_rows = []
        for idx, app in enumerate(self.repo["apps"]):
            haystack = " ".join([
                str(app.get("name", "")), str(app.get("id", "")),
                str(app.get("developer", "")), " ".join(app.get("tags") or []),
                " ".join(app.get("categories") or []),
            ]).lower()
            if query and query not in haystack:
                continue
            rel = latest_release(app)
            self.app_tree.insert(
                "", tk.END, iid=str(idx),
                values=(app.get("name") or "(unnamed)",
                        app.get("id") or "(no id)",
                        rel.get("versionName", "") if rel else "—"),
            )
            self._tree_rows.append(idx)
        total = len(self.repo["apps"])
        shown = len(self._tree_rows)
        self.app_count.configure(text=f"({shown}/{total})" if shown != total else f"({total})")
        if select is not None and str(select) in self.app_tree.get_children():
            self.app_tree.selection_set(str(select))
            self.app_tree.see(str(select))

    def _on_app_select(self, _event=None) -> None:
        sel = self.app_tree.selection()
        if not sel:
            return
        idx = int(sel[0])
        if idx == self.current_index:
            return
        self._store_current_app()
        self.current_index = idx
        self._load_app(idx)

    def _load_app(self, idx: int) -> None:
        app = self.repo["apps"][idx]
        self._loading = True
        try:
            for key, _label, _ph in DETAIL_FIELDS:
                value = app.get(key, "")
                if key in ("categories", "tags"):
                    value = _list_to_csv(value)
                self._set_entry(self._entries[key], value)
            for key, _label, _ph in LINK_FIELDS:
                self._set_entry(self._entries[key], app.get(key, ""))
            self._set_text("description", app.get("description", ""))
            self._set_text("screenshots", "\n".join(app.get("screenshots") or []))
            self.rel_tree.delete(*self.rel_tree.get_children())
            for i, rel in enumerate(app.get("releases") or []):
                self.rel_tree.insert("", tk.END, iid=str(i), values=(
                    rel.get("versionName", ""),
                    rel.get("versionCode", ""),
                    rel.get("channel", ""),
                    rel.get("size", ""),
                    rel.get("url", ""),
                ))
            self._release_row = None
            self._clear_release_form()
        finally:
            self._loading = False

    def _store_current_app(self) -> None:
        if self.current_index is None:
            return
        if self.current_index >= len(self.repo["apps"]):
            return
        app = self.repo["apps"][self.current_index]
        for key, _label, _ph in DETAIL_FIELDS:
            value = self._entry_value(self._entries[key])
            if key in ("categories", "tags"):
                app[key] = _csv_to_list(value)
            else:
                app[key] = value
        for key, _label, _ph in LINK_FIELDS:
            app[key] = self._entry_value(self._entries[key])
        app["description"] = self._text_value("description")
        app["screenshots"] = _lines_to_list(self._text_value("screenshots"))
        self._commit_pending_release()

    # -- app actions ------------------------------------------------------- #

    def add_app(self) -> None:
        self._store_current_app()
        self.repo["apps"].append(new_app())
        self.current_index = len(self.repo["apps"]) - 1
        self._mark_dirty()
        self._refresh_app_list(select=self.current_index)
        self._load_app(self.current_index)
        self._entries["id"].focus_set()

    def duplicate_app(self) -> None:
        if self.current_index is None:
            return
        self._store_current_app()
        clone = copy.deepcopy(self.repo["apps"][self.current_index])
        clone["id"] = (clone.get("id") or "app") + ".copy"
        clone["name"] = (clone.get("name") or "App") + " (copy)"
        self.repo["apps"].insert(self.current_index + 1, clone)
        self.current_index += 1
        self._mark_dirty()
        self._refresh_app_list(select=self.current_index)
        self._load_app(self.current_index)

    def delete_app(self) -> None:
        if self.current_index is None:
            return
        removed = self.current_index
        app = self.repo["apps"][removed]
        label = app.get("name") or app.get("id") or "this app"
        if not messagebox.askyesno("Delete app", f"Delete “{label}”?", parent=self):
            return
        del self.repo["apps"][removed]
        self.current_index = None
        self._mark_dirty()
        if self.repo["apps"]:
            new_index = min(removed, len(self.repo["apps"]) - 1)
            self.current_index = new_index
            self._refresh_app_list(select=new_index)
            self._load_app(new_index)
        else:
            self._refresh_app_list()
            self._load_app_empty()

    def _load_app_empty(self) -> None:
        self._loading = True
        try:
            for key, _label, _ph in DETAIL_FIELDS:
                self._set_entry(self._entries[key], "")
            for key, _label, _ph in LINK_FIELDS:
                self._set_entry(self._entries[key], "")
            self._set_text("description", "")
            self._set_text("screenshots", "")
            self.rel_tree.delete(*self.rel_tree.get_children())
            self._clear_release_form()
        finally:
            self._loading = False

    def move_app(self, delta: int) -> None:
        if self.current_index is None:
            return
        self._store_current_app()
        new = self.current_index + delta
        apps = self.repo["apps"]
        if new < 0 or new >= len(apps):
            return
        apps[self.current_index], apps[new] = apps[new], apps[self.current_index]
        self.current_index = new
        self._mark_dirty()
        self._refresh_app_list(select=new)

    # -- releases ---------------------------------------------------------- #

    def _clear_release_form(self) -> None:
        self._loading = True
        try:
            self._set_text("changelog", "")
            for key, _label, _ph in RELEASE_FIELDS:
                defaults = new_release()
                self._set_entry(self._release_entries[key], str(defaults.get(key, "")))
            self._set_entry(self._release_entries["versionName"], "")
            self._set_entry(self._release_entries["url"], "")
            self._set_entry(self._release_entries["sha256"], "")
            self._set_entry(self._release_entries["size"], "0")
            self._set_entry(self._release_entries["added"], dt.date.today().isoformat())
        finally:
            self._loading = False

    def _on_release_select(self, _event=None) -> None:
        sel = self.rel_tree.selection()
        if not sel or self.current_index is None:
            return
        iid = sel[0]
        releases = self.repo["apps"][self.current_index].get("releases") or []
        if int(iid) >= len(releases):
            return
        rel = releases[int(iid)]
        self._loading = True
        try:
            for key, _label, _ph in RELEASE_FIELDS:
                self._set_entry(self._release_entries[key], str(rel.get(key, "") if rel.get(key) is not None else ""))
            self._set_text("changelog", rel.get("changelog", ""))
        finally:
            self._loading = False
        self._release_row = iid

    def _read_release_form(self) -> dict:
        def as_int(key: str, default: int = 0) -> int:
            raw = self._entry_value(self._release_entries[key])
            try:
                return int(float(raw))
            except (TypeError, ValueError):
                return default

        rel = new_release()
        rel["versionName"] = self._entry_value(self._release_entries["versionName"])
        rel["versionCode"] = as_int("versionCode", 0)
        rel["channel"] = self._entry_value(self._release_entries["channel"]) or "stable"
        rel["url"] = self._entry_value(self._release_entries["url"])
        rel["size"] = as_int("size", 0)
        rel["sha256"] = self._entry_value(self._release_entries["sha256"])
        rel["minSdkVersion"] = as_int("minSdkVersion", 0)
        rel["targetSdkVersion"] = as_int("targetSdkVersion", 0)
        rel["added"] = self._entry_value(self._release_entries["added"])
        rel["changelog"] = self._text_value("changelog")
        return rel

    def _commit_pending_release(self) -> None:
        """If a release row is selected, write the form back into it."""
        if self._release_row is None or self.current_index is None:
            return
        releases = self.repo["apps"][self.current_index].setdefault("releases", [])
        i = int(self._release_row)
        if 0 <= i < len(releases):
            releases[i] = self._read_release_form()

    def add_release(self) -> None:
        if self.current_index is None:
            messagebox.showinfo("No app selected", "Select or create an app first.", parent=self)
            return
        # Persist both the app fields and any pending release edits before the
        # form is reloaded below, otherwise typed-in changes would be lost.
        self._store_current_app()
        releases = self.repo["apps"][self.current_index].setdefault("releases", [])
        if releases:
            nxt = max(int(r.get("versionCode") or 0) for r in releases) + 1
        else:
            nxt = 1
        rel = self._read_release_form()
        if not rel["versionCode"]:
            rel["versionCode"] = nxt
        releases.append(rel)
        self._mark_dirty()
        self._load_app(self.current_index)
        self.rel_tree.selection_set(str(len(releases) - 1))
        self._on_release_select()

    def update_release(self) -> None:
        if not self.rel_tree.selection() or self.current_index is None:
            messagebox.showinfo("No release selected", "Select a release in the list first.", parent=self)
            return
        self._store_current_app()
        i = int(self.rel_tree.selection()[0])
        rel = self._read_release_form()
        self.repo["apps"][self.current_index]["releases"][i] = rel
        self._mark_dirty()
        self._load_app(self.current_index)
        if str(i) in self.rel_tree.get_children():
            self.rel_tree.selection_set(str(i))
        self._release_row = str(i)

    def remove_release(self) -> None:
        if not self.rel_tree.selection() or self.current_index is None:
            return
        self._store_current_app()
        i = int(self.rel_tree.selection()[0])
        rel = self.repo["apps"][self.current_index]["releases"][i]
        if not messagebox.askyesno("Remove release", f"Remove version {rel.get('versionName') or i}?", parent=self):
            return
        del self.repo["apps"][self.current_index]["releases"][i]
        self._release_row = None
        self._mark_dirty()
        self._load_app(self.current_index)

    def pick_apk(self) -> None:
        if self.current_index is None:
            messagebox.showinfo("No app selected", "Select or create an app first.", parent=self)
            return
        path = filedialog.askopenfilename(
            title="Choose an APK",
            filetypes=[("Android package", "*.apk"), ("All files", "*.*")],
        )
        if not path:
            return
        size = os.path.getsize(path)
        try:
            digest = _sha256_of(path)
        except OSError as exc:
            messagebox.showerror("Read error", str(exc), parent=self)
            return
        self._set_entry(self._release_entries["size"], str(size))
        self._set_entry(self._release_entries["sha256"], digest)
        if not self._entry_value(self._release_entries["versionName"]):
            self._set_entry(self._release_entries["versionName"], os.path.basename(path))
        self._set_status(f"Filled size and SHA-256 from {os.path.basename(path)}")

    # -- file operations --------------------------------------------------- #

    def new_file(self) -> None:
        if not self._confirm_discard():
            return
        self.repo = new_repo()
        self.path = None
        self.current_index = None
        self.dirty = False
        self._refresh_repo_form()
        self._refresh_app_list()
        self._load_app_empty()
        self.refresh_preview()
        self._update_title()
        self._set_status("New repository")

    def open_file(self) -> None:
        if not self._confirm_discard():
            return
        path = filedialog.askopenfilename(
            title="Open repository index",
            filetypes=[("JSON", "*.json"), ("All files", "*.*")],
        )
        if path:
            self._load_path(path)

    def fetch_url(self) -> None:
        if not self._confirm_discard():
            return
        url = _simple_prompt(self, "Fetch repository", "Repository index URL:")
        if not url:
            return
        try:
            with urllib.request.urlopen(url, timeout=20) as resp:
                raw = resp.read().decode("utf-8")
            data = json.loads(raw)
        except Exception as exc:  # noqa: BLE001 - surface any failure to the user
            messagebox.showerror("Fetch failed", str(exc), parent=self)
            return
        self.repo = normalize_repo(data)
        self.path = None
        self.current_index = None
        self.dirty = True
        self._refresh_repo_form()
        self._refresh_app_list(select=0 if self.repo["apps"] else None)
        if self.repo["apps"]:
            self.current_index = 0
            self._load_app(0)
        else:
            self._load_app_empty()
        self.refresh_preview()
        self._update_title()
        self._set_status(f"Fetched {len(self.repo['apps'])} app(s) from URL")

    def _load_path(self, path: str) -> None:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                data = json.load(fh)
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Open failed", str(exc), parent=self)
            return
        if not isinstance(data, dict):
            messagebox.showerror("Open failed", "Repository JSON must be an object.", parent=self)
            return
        self.repo = normalize_repo(data)
        self.path = path
        self.current_index = None
        self.dirty = False
        self._refresh_repo_form()
        self._refresh_app_list(select=0 if self.repo["apps"] else None)
        if self.repo["apps"]:
            self.current_index = 0
            self._load_app(0)
        else:
            self._load_app_empty()
        self.refresh_preview()
        self._update_title()
        self._set_status(f"Opened {os.path.basename(path)}")

    def save_file(self) -> bool:
        if not self.path:
            return self.save_file_as()
        return self._write(self.path)

    def save_file_as(self) -> bool:
        path = filedialog.asksaveasfilename(
            title="Save repository index",
            defaultextension=".json",
            initialfile=os.path.basename(self.path) if self.path else DEFAULT_INDEX_NAME,
            filetypes=[("JSON", "*.json"), ("All files", "*.*")],
        )
        if not path:
            return False
        return self._write(path)

    def _write(self, path: str) -> bool:
        self._store_current_app()
        self._collect_repo_form()
        self.repo["lastUpdated"] = _now_iso()
        data = normalize_repo(self.repo)
        try:
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(data, fh, indent=2, ensure_ascii=False)
                fh.write("\n")
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Save failed", str(exc), parent=self)
            return False
        self.repo = data
        self.path = path
        self.dirty = False
        self._update_title()
        self._set_status(f"Saved {os.path.basename(path)}")
        self.refresh_preview()
        return True

    def export_preview(self) -> None:
        self._store_current_app()
        self._collect_repo_form()
        path = filedialog.asksaveasfilename(
            title="Export JSON preview",
            defaultextension=".json",
            initialfile=DEFAULT_INDEX_NAME,
            filetypes=[("JSON", "*.json")],
        )
        if not path:
            return
        try:
            with open(path, "w", encoding="utf-8") as fh:
                json.dump(normalize_repo(self.repo), fh, indent=2, ensure_ascii=False)
                fh.write("\n")
        except Exception as exc:  # noqa: BLE001
            messagebox.showerror("Export failed", str(exc), parent=self)
            return
        self._set_status(f"Exported {os.path.basename(path)}")

    # -- preview / validation ---------------------------------------------- #

    def refresh_preview(self) -> None:
        self._store_current_app()
        self._collect_repo_form()
        data = normalize_repo(self.repo)
        self.preview.delete("1.0", tk.END)
        self.preview.insert("1.0", json.dumps(data, indent=2, ensure_ascii=False))

    def copy_preview(self) -> None:
        self.refresh_preview()
        self.clipboard_clear()
        self.clipboard_append(self.preview.get("1.0", "end-1c"))
        self._set_status("JSON copied to clipboard")

    def validate_repo(self) -> list[str]:
        self._store_current_app()
        self._collect_repo_form()
        problems: list[str] = []
        if not self.repo.get("name"):
            problems.append("Repository: name is empty.")
        seen_ids: set[str] = set()
        for i, app in enumerate(self.repo["apps"]):
            label = app.get("name") or app.get("id") or f"#{i + 1}"
            if not app.get("id"):
                problems.append(f"{label}: missing package ID.")
            elif app["id"] in seen_ids:
                problems.append(f"{label}: duplicate package ID “{app['id']}”.")
            else:
                seen_ids.add(app["id"])
            if not app.get("name"):
                problems.append(f"{label}: missing app name.")
            releases = app.get("releases") or []
            if not releases:
                problems.append(f"{label}: has no releases.")
            for rel in releases:
                if not rel.get("url"):
                    problems.append(f"{label} {rel.get('versionName') or ''}: release has no APK URL.")
                if not rel.get("versionCode"):
                    problems.append(f"{label} {rel.get('versionName') or ''}: version code is 0.")
        if problems:
            messagebox.showwarning(
                "Validation",
                "Found {} problem(s):\n\n{}".format(len(problems), "\n".join(problems[:25])),
                parent=self,
            )
            self._set_status(f"Validation: {len(problems)} problem(s)")
        else:
            messagebox.showinfo("Validation", "Repository looks good.", parent=self)
            self._set_status("Validation passed")
        return problems

    def show_about(self) -> None:
        messagebox.showinfo(
            "About Repo Forge",
            "Repo Forge\n\n"
            "GUI editor for OpenAppStore repository indexes.\n"
            "Produces a JSON document (repo.json) that the Android app reads.\n\n"
            "Format version: {}".format(FORMAT_VERSION),
            parent=self,
        )

    # -- shutdown ---------------------------------------------------------- #

    def _on_close(self) -> None:
        if self._confirm_discard():
            self.destroy()


def _simple_prompt(parent: tk.Misc, title: str, label: str) -> str | None:
    """Minimal single-line input dialog (avoids depending on simpledialog styling)."""
    dlg = tk.Toplevel(parent)
    dlg.title(title)
    dlg.transient(parent)
    dlg.grab_set()
    dlg.resizable(False, False)
    ttk.Label(dlg, text=label).pack(padx=14, pady=(14, 6), anchor=tk.W)
    var = tk.StringVar()
    entry = ttk.Entry(dlg, textvariable=var, width=64)
    entry.pack(padx=14, fill=tk.X)
    entry.focus_set()
    result: dict[str, str | None] = {"value": None}

    def ok(_e=None) -> None:
        result["value"] = var.get().strip()
        dlg.destroy()

    def cancel(_e=None) -> None:
        result["value"] = None
        dlg.destroy()

    row = ttk.Frame(dlg)
    row.pack(padx=14, pady=12, fill=tk.X)
    ttk.Button(row, text="Cancel", command=cancel).pack(side=tk.RIGHT)
    ttk.Button(row, text="OK", command=ok).pack(side=tk.RIGHT, padx=(0, 6))
    entry.bind("<Return>", ok)
    dlg.bind("<Escape>", cancel)
    parent.wait_window(dlg)
    return result["value"]


def main(argv: list[str]) -> int:
    path = argv[1] if len(argv) > 1 else None
    app = RepoForge(path)
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
