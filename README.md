# owl 🦉

> **O**bservant **W**atcher of **L**ines — a file viewer for AGNOS / Cyrius

`owl` reads files and prints them to your terminal — with syntax highlighting, line numbers, and git-aware decorations when you want them, and completely out of the way when you don't. Think `cat`, but it sees more.

---

## Why owl?

`cat` is fast and universal, but it hasn't changed much since the 1970s. `owl` keeps the parts of `cat` that work (pipe-friendly, predictable, no nonsense) and adds the things you actually want when reading files at a terminal: colors, line numbers, and a pager that kicks in when it should.

Pipe `owl` into another command and it quietly steps aside — no decorations, no surprises, just bytes.

---

## Install

```sh
# AGNOS / Cyrius native package manager
pkg install owl

# From source — Cyrius toolchain 5.6.44+ on $PATH
git clone https://github.com/MacCracken/owl
cd owl
cyrius deps                            # populate lib/ from cyrius.cyml
cyrius build src/main.cyr build/owl    # → build/owl
```

`lib/` is gitignored and regenerated on demand from
[cyrius.cyml](cyrius.cyml) — `cyrius deps` is mandatory after a fresh
checkout.

---

## Quick start

```sh
owl file.txt              # show a file, decorated
owl a.py b.py c.py        # show several files in order
owl -p file.txt           # plain output, no decorations (like cat)
echo "hello" | owl        # read from stdin
owl huge.log | head       # pipe-safe; no broken-pipe errors
```

If you've used `cat`, you already know how to use `owl`. The defaults just do more.

---

## What you get by default

When you run `owl file.py` in a terminal:

- **Syntax highlighting** for the language, auto-detected from the filename or shebang
- **Line numbers** in a narrow gutter on the left
- **A file header** so you know what you're looking at
- **Git markers** in the gutter if the file is tracked and has changes
- **Automatic paging** if the output is longer than your terminal

When you pipe `owl` somewhere else, all of that turns off automatically. You get raw bytes, same as `cat`.

---

## Common recipes

```sh
# View a config file with line numbers but no colors
owl --color never nginx.conf

# Force a language when the extension lies
owl --language yaml config.txt

# Show whitespace and non-printables
owl -A script.sh

# Read three files and pipe into a pager yourself
owl -p a.log b.log c.log | less

# Use a different theme for the session
OWL_THEME=high-contrast owl README.md

# List everything owl knows how to highlight
owl --list-languages

# See available themes
owl --list-themes
```

---

## Flags cheat sheet

| Flag | What it does |
|------|--------------|
| `-n` / `-N` | Show / hide line numbers |
| `-p` | Plain mode — behaves like `cat` |
| `-A` | Show tabs, newlines, and other non-printables |
| `--color <auto\|always\|never>` | Control color output |
| `--paging <auto\|always\|never>` | Control paging |
| `--theme <name>` | Pick a syntax highlighting theme |
| `--language <lang>` | Force a language for highlighting |
| `--tabs <n>` | Render tabs as N spaces (default 4, 0 keeps literal tabs) |
| `--wrap <auto\|never\|character>` | Line wrapping behavior |
| `--style <list>` | Fine-grained decoration control |
| `-h`, `-V` | Help and version |

Run `owl --help` for the full list.

---

## Configuration

`owl` reads a config file at the platform config location (something like `~/.config/owl/config.toml` — check `owl --help` for the exact path on your system).

Example config:

```toml
theme = "nocturne-dark"
paging = "auto"
tabs = 2
wrap = "auto"

[style]
numbers = true
header = true
changes = true     # git gutter markers
```

Precedence, lowest to highest: built-in defaults → config file → environment variables → command-line flags. Whatever you put on the command line always wins.

### Environment variables

- `OWL_THEME` — default theme
- `OWL_PAGER` — pager to use (overrides system default)
- `OWL_CONFIG` — path to config file
- `NO_COLOR` — set to anything to disable color everywhere
- `PAGER` — fallback if `OWL_PAGER` is unset

---

## How owl decides what to do

`owl` tries hard to do the right thing without being asked. The rule is simple: **if your terminal is going to read the output, decorate it. If anything else is going to read the output, don't.**

That means:
- `owl file.txt` at a prompt → colors, numbers, pager
- `owl file.txt | grep foo` → plain bytes, no colors
- `owl file.txt > out.txt` → plain bytes, no colors
- `owl file.txt | less -R` → colors preserved, no owl-side paging

You can override any of this with `--color always`, `--paging never`, etc.

---

## Scripting with owl

Short version: don't, use `cat`. But if you want to, use `-p`:

```sh
owl -p config.toml   # guaranteed byte-identical to cat
```

In plain mode, `owl` matches `cat`'s behavior closely enough that you can substitute it in scripts. Exit codes follow Unix conventions (see below).

---

## Exit codes

| Code | Meaning |
|------|---------|
| 0 | Everything worked |
| 1 | Some files failed but some succeeded |
| 2 | You used the command wrong (bad flag) |
| 3 | I/O error on output |
| 4 | All files failed to open |

Broken pipes (`owl big.log \| head`) exit cleanly without noise.

---

## Troubleshooting

**"Colors look wrong / ugly"**
Try a different theme: `owl --list-themes`, then `OWL_THEME=<name>` or set it in your config.

**"No colors at all"**
Check `$NO_COLOR` — if it's set, colors are disabled globally. Also confirm your terminal supports 256 colors or truecolor.

**"owl is slow on huge files"**
Very large files may trigger a size-based fallback that disables highlighting. Use `-p` for raw speed, or pipe to a pager manually.

**"It won't show my binary file"**
By design. Use `-p` to force, or use a hex viewer — `owl` isn't one.

**"Line numbers are showing up when I pipe to another command"**
Shouldn't happen. If it does, it's a bug — please report. As a workaround, `-p` or `--color never --no-number`.

---

## Reporting bugs

File issues at `<repo url>`. Helpful things to include:
- `owl --version`
- Your OS and terminal emulator
- A minimal file that triggers the issue, if possible
- The exact command and the output you got vs. what you expected

---

## Name

**owl** traces to the same Proto-Indo-European root (*\*ulū-*, "to howl/hoot") as Sanskrit **ulūka** (उलूक). In AGNOS's naming lineage — the Sanskrit wing that yields *vyakarana*, *vidya*, and *yukti* — **Uluka** is the progenitor. In the Rigveda, Ulūka is a messenger; in later tradition, the vāhana of Lakshmi: a bird that sees clearly in the dark, which is what this tool tries to do for source at a terminal.

---

## License

<license to be chosen>

---

*owl — see your files clearly.* 🦉
