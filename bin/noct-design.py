#!/usr/bin/env python3
"""noct-design.py -- the TOML half of bin/noct-design.

  noct-design.py render <design.toml> <design dir> <config home> <state home>
  noct-design.py check  <design dir> <tracked noctalia dir>

`render` checks everything, then writes the generated files and prints one IPC
call per line for noct-design to run; on any error it writes nothing. `check`
is tests/lint.sh designs.
"""

import json
import sys
import tomllib
from pathlib import Path

KINDS = {"builtin", "custom", "wallpaper", "community"}

NUM, INT, STR, BOOL = "number", "integer", "string", "boolean"

# What each table may hold, and of what type. None: any Noctalia key, typed
# like the tracked value it replaces.
KNOWN = {
    "design":   {"label": STR, "description": STR, "palette": STR},
    "noctalia": None,
    "pill":     {"fill": STR, "opacity": NUM, "radius": NUM, "padding": NUM,
                 "border": STR, "border_width": NUM},
    "hyprland": {"rounding": INT, "border_size": INT, "gaps_in": INT, "gaps_out": INT,
                 "border": STR, "inactive_alpha": NUM},
    "glass":    {"window": NUM, "terminal": NUM, "adaptive": BOOL, "blur_size": INT,
                 "blur_passes": INT, "blur_brightness": NUM, "blur_contrast": NUM,
                 "blur_vibrancy": NUM, "blur_xray": BOOL},
    "nvim":     {"colorscheme": STR},
    "fonts":    {"ui": STR, "mono": STR, "size": NUM, "terminal_size": NUM},
}

GENERATED = "90-design.toml"
SAVED = "design-saved.json"


class DesignError(Exception):
    pass


def load(path):
    try:
        with open(path, "rb") as f:
            return tomllib.load(f)
    except (OSError, tomllib.TOMLDecodeError) as e:
        raise DesignError(f"{path}: {e}") from None


def merge(base, over):
    """Tables merge, everything else replaces -- lists too, as Noctalia does."""
    out = dict(base)
    for k, v in over.items():
        out[k] = merge(out[k], v) if isinstance(v, dict) and isinstance(out.get(k), dict) else v
    return out


def paths(d, prefix=""):
    """Every dotted key path to a non-table value."""
    for k, v in d.items():
        if isinstance(v, dict):
            yield from paths(v, f"{prefix}{k}.")
        else:
            yield f"{prefix}{k}"


def get(d, path):
    for part in path.split("."):
        if not isinstance(d, dict) or part not in d:
            return None
        d = d[part]
    return d


def kind(v):
    if isinstance(v, bool):
        return BOOL
    if isinstance(v, int):
        return INT
    if isinstance(v, float):
        return NUM
    if isinstance(v, str):
        return STR
    return type(v).__name__


def an(word):
    return ("an " if word[0] in "aeiou" else "a ") + word


def fits(v, want):
    got = kind(v)
    return got == want or {got, want} <= {NUM, INT}


def tracked_noctalia(noct_dir):
    """The tracked Noctalia config, merged in Noctalia's order, without ours."""
    merged = {}
    for f in sorted(Path(noct_dir).glob("*.toml")):
        if f.name != GENERATED:
            merged = merge(merged, load(f))
    return merged


# Numbers are never negative; these are fractions too.
FRACTIONS = {("hyprland", "inactive_alpha"), ("glass", "window"), ("glass", "terminal"),
             ("pill", "opacity")}


def noctalia_table(design):
    """The design's Noctalia keys, the shell font from [fonts] included."""
    noct = dict(design.get("noctalia", {}))
    ui = design.get("fonts", {}).get("ui")
    return merge(noct, {"shell": {"font_family": ui}}) if ui else noct


def problems(design, tracked):
    """What is wrong with one design, as sentences: the check render runs before writing."""
    out = []
    for table, keys in design.items():
        if table not in KNOWN:
            out.append(f"[{table}] is read by nothing")
        elif not isinstance(keys, dict):
            out.append(f"[{table}] is not a table")
        elif KNOWN[table] is not None:
            for k, v in keys.items():
                want = KNOWN[table].get(k)
                if want is None:
                    out.append(f"[{table}] {k} is read by nothing")
                elif not fits(v, want):
                    out.append(f"[{table}] {k} is {an(kind(v))}, not {an(want)}")
                elif want in (NUM, INT) and (v < 0 or ((table, k) in FRACTIONS and v > 1)):
                    out.append(f"[{table}] {k} = {v} is out of range")
    if out:
        return out  # the checks below assume every table is a table of the right types

    palette = design.get("design", {}).get("palette", "")
    if palette and palette.split(" ", 1)[0] not in KINDS:
        out.append(f"palette '{palette}' is not '<{'|'.join(sorted(KINDS))}> <name>'")
    if design.get("hyprland", {}).get("border", "gradient") not in ("flat", "gradient"):
        out.append("[hyprland] border is flat or gradient")
    if any("|" in str(design.get("fonts", {}).get(k, "")) for k in ("ui", "mono")):
        out.append("[fonts] a font name cannot contain '|'")
    noct = noctalia_table(design)
    for path in paths(noct):
        have, mine = get(tracked, path), get(noct, path)
        if have is None:
            out.append(f"{path} has no value in the tracked config to check its type against")
        elif not fits(mine, kind(have)):
            out.append(f"{path} is {an(kind(mine))}, where the tracked config has {an(kind(have))}")
    if design.get("pill"):
        try:
            with_pill({}, tracked, design["pill"])
        except DesignError as e:
            out.append(str(e))
    return out


# --- writing ------------------------------------------------------------------

def literal(v):
    """A TOML value, which is also what `noctalia msg config-set` takes."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, str):
        if "'" not in v and "\n" not in v:
            return f"'{v}'"
        return json.dumps(v)  # a JSON string is a valid TOML basic string
    if isinstance(v, list):
        return "[" + ", ".join(literal(x) for x in v) + "]"
    raise DesignError(f"cannot write {v!r} as TOML")


def lua_literal(v):
    if isinstance(v, str):
        return json.dumps(v)  # and a valid Lua string
    return literal(v)


def is_table_list(v):
    return isinstance(v, list) and v and all(isinstance(x, dict) for x in v)


def emit(d, path=()):
    """TOML lines for a table: scalars, then sub-tables, then arrays of tables."""
    lines = [f"{k} = {literal(v)}" for k, v in d.items()
             if not isinstance(v, dict) and not is_table_list(v)]
    for k, v in d.items():
        if isinstance(v, dict):
            sub = emit(v, path + (k,))
            # A table holding only tables needs no header of its own.
            if not sub or sub[0] != "":
                sub = ["", f"[{'.'.join(path + (k,))}]"] + sub
            lines += sub
    for k, v in d.items():
        if is_table_list(v):
            for item in v:
                lines += ["", f"[[{'.'.join(path + (k,))}]]"] + emit(item, path + (k,))
    return lines


def lua_table(header, d):
    """A Lua file returning `d`, or None for an empty table (no file)."""
    if not d:
        return None
    body = "\n".join(f"    {k} = {lua_literal(v)}," for k, v in d.items())
    return f"-- {header}\nreturn {{\n{body}\n}}\n"


def kitty_fonts(header, fonts):
    """Always written, since kitty.conf includes it; empty keeps kitty.conf's font."""
    lines = [f"# {header}"]
    if fonts.get("mono"):
        lines.append(f"font_family {fonts['mono']}")
    if fonts.get("terminal_size"):
        lines.append(f"font_size {fonts['terminal_size']}")
    return "\n".join(lines) + "\n"


def write(path, text):
    """Replace or remove one file; the rename keeps a reader from seeing half of it."""
    if text is None:
        path.unlink(missing_ok=True)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(text)
    tmp.replace(path)


# --- render -------------------------------------------------------------------

def with_pill(noct, tracked, pill):
    """[pill] merged into the bar's centre capsule group, the whole list written.

    A later capsule_group list replaces the earlier one (measured 2026-11-25,
    Noctalia 5.6.0), so a partial group would drop the members.
    """
    bar = get(tracked, "bar.default") or {}
    centre = bar.get("center", [])
    if len(centre) != 1 or not str(centre[0]).startswith("group:"):
        raise DesignError(f"[pill]: the bar's centre lane is {centre}, not one capsule group")
    gid = centre[0][len("group:"):]
    groups = bar.get("capsule_group", [])
    if not any(g.get("id") == gid for g in groups):
        raise DesignError(f"[pill]: no capsule_group has id '{gid}'")
    groups = [dict(g, **pill) if g.get("id") == gid else g for g in groups]
    return merge(noct, {"bar": {"default": {"capsule_group": groups}}})


def settings_ipc(base, state, saved):
    """IPC for the Settings UI layer, which loads after every .toml and wins.

    A key it holds that this design sets is overridden, and the value it held
    is saved; a saved key this design does not set gets that value back. So a
    switch only ever undoes what an earlier switch did.
    """
    ipc, keep = [], {}
    for path in sorted(set(paths(base)) | set(saved)):
        held = get(state, path)
        want = get(base, path)
        if want is not None:
            if path in saved:
                keep[path] = saved[path]
            elif held is not None:
                keep[path] = held
            if held is None:
                continue  # not in the Settings UI layer: 90-design.toml carries it
        else:
            want = saved[path]
        if held != want:
            ipc.append(f"config-set {path} {literal(want)}")
    return ipc, keep


def render(design_path, design_dir, config_home, state_home):
    design_path = Path(design_path)
    noct_dir = Path(config_home) / "noctalia"
    state_dir = Path(state_home) / "noctalia"
    saved_file = state_dir / SAVED

    # Read and check everything first, so an error writes nothing.
    design = load(design_path)
    tracked = tracked_noctalia(noct_dir)
    found = problems(design, tracked)
    if found:
        raise DesignError(f"{design_path}: " + "; ".join(found))
    settings = state_dir / "settings.toml"
    state = load(settings) if settings.exists() else {}
    try:
        saved = json.loads(saved_file.read_text()) if saved_file.exists() else {}
    except (OSError, ValueError) as e:
        raise DesignError(f"{saved_file}: {e}") from None

    header = (f"Generated by noct-design from ~/.config/noct-design/{design_path.stem}.toml."
              " Edit that and run `noct-design apply`.")
    base = noctalia_table(design)
    noct = with_pill(base, tracked, design["pill"]) if design.get("pill") else base
    if design.get("pill") and get(state, "bar.default.capsule_group") is not None:
        print(f"noct-design: {settings} holds bar.default.capsule_group, which beats [pill]",
              file=sys.stderr)
    ipc, keep = settings_ipc(base, state, saved)

    fonts = design.get("fonts", {})
    glass = design.get("glass", {})
    files = {
        noct_dir / GENERATED: "\n".join([f"# {header}"] + emit(noct)) + "\n" if noct else None,
        Path(config_home) / "hypr" / "generated" / "design.lua":
            lua_table(header, design.get("hyprland", {})),
        state_dir / "design-nvim.lua": lua_table(header, design.get("nvim", {})),
        Path(config_home) / "kitty" / "generated-design.conf": kitty_fonts(header, fonts),
        state_dir / "design-glass.conf":
            f"# {header}\n" + "".join(f"{k} = {literal(v)}\n" for k, v in glass.items())
            if glass else None,
        saved_file: json.dumps(keep, indent=2) + "\n" if keep else None,
    }

    for path, text in files.items():
        write(path, text)
    for line in ipc:
        print(line)
    if fonts:
        print(f"fonts {fonts.get('ui', '')}|{fonts.get('mono', '')}|{fonts.get('size', '')}")
    palette = design.get("design", {}).get("palette", "")
    if palette:
        print(f"palette {palette}")


# --- check --------------------------------------------------------------------

def check(design_dir, noct_dir):
    """One line per problem; nothing when every design is sound."""
    tracked = tracked_noctalia(noct_dir)
    files = sorted(Path(design_dir).glob("*.toml"))
    if not any(f.stem == "glass" for f in files):
        print(f"{design_dir}/glass.toml is missing: it is the design in effect before any is picked")
    for f in files:
        for p in problems(load(f), tracked):
            print(f"{f}: {p}")


if __name__ == "__main__":
    cmd, args = (sys.argv[1], sys.argv[2:]) if len(sys.argv) > 1 else ("", [])
    try:
        if cmd == "render" and len(args) == 4:
            render(*args)
        elif cmd == "check" and len(args) == 2:
            check(*args)
        else:
            sys.exit(__doc__)
    except DesignError as e:
        sys.exit(f"noct-design: {e}")
