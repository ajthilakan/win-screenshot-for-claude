# win-screenshot-for-claude

Paste screenshots into **Claude Code on Windows** — without the broken clipboard.

`shot` turns a `Win+Shift+S` capture into a saved PNG and drops its **file path**
on your clipboard, so you can hand it to Claude Code in one paste. An optional
`shot-watch` toggle does it automatically for capture-heavy sessions.

---

## The problem

Claude Code reads images you paste into the prompt — except **raw clipboard image
paste is broken on native Windows**. You snip with `Win+Shift+S`, hit `Ctrl+V`, and
nothing attaches.

- [anthropics/claude-code#26679](https://github.com/anthropics/claude-code/issues/26679) — *Feature request: paste images from clipboard directly into Claude Code (Windows)*
- [anthropics/claude-code#9124](https://github.com/anthropics/claude-code/issues/9124) — *Bug: image paste with Ctrl+V not working on Windows*

The usual workarounds are clunky: save the file somewhere by hand, dig up its path,
or round-trip the image through another app. If you're configuring something and
sharing lots of screenshots, that friction adds up fast.

## The fix

Claude Code **does** read an image reliably when you give it a **file path** as text.
So this tool closes the gap:

```
Win+Shift+S  →  shot  →  path on clipboard  →  paste into Claude Code
```

That's it. No clipboard hacks, no manual file wrangling.

## Install

### 1. Base install (PowerShell) — required

Requires Windows PowerShell 5.1+ (ships with Windows). From a PowerShell prompt:

```powershell
git clone https://github.com/ajthilakan/win-screenshot-for-claude.git
cd win-screenshot-for-claude
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer copies the scripts to `~\.claude\scripts`, creates `~\.claude\shots`,
and adds one line to your PowerShell `$PROFILE` so the commands load in every
terminal. Open a new terminal afterward.

### 2. Optional — use from Git Bash or Claude Code's `!` prompt

The commands are PowerShell. If you'd rather call them from **Git Bash** — or from
Claude Code's `!` prompt, which defaults to Git Bash on Windows — run the bash-shim
installer **after** step 1, from a Git Bash terminal:

```bash
./install-bash-shims.sh
```

It drops a thin wrapper for each command into `~/.local/bin` (on Git for Windows'
default PATH), so `shot`, `shot-watch`, `shot-clear`, `shot-save`, and
`shot-save-config` all work from bash too. Each wrapper just calls the PowerShell
script — PowerShell stays the engine. See the [`!` prompt notes](#running-it-from-claude-codes--prompt)
for per-command caveats.

## Usage

```powershell
shot                       # capture clipboard image -> PNG, copy its path to the clipboard
shot-watch                 # live feed: prints + copies the path for every capture (Ctrl+C to stop)
shot-clear                 # delete all saved screenshots (prompts; -Force to skip)
shot-save all              # move every saved shot into your vault folder
shot-save <name...>        # move only the named shots into your vault folder
shot-save-config '<path>'  # set the vault destination (run with no path to show it)
```

**Manual mode** — grab one or two screenshots:

1. `Win+Shift+S`, select a region.
2. Run `shot`. It saves `~\.claude\shots\shot-<timestamp>.png` and copies the path.
3. `Ctrl+V` the path into Claude Code and send.

**Watch mode** — a config-heavy session with lots of captures:

1. Run `shot-watch` in a spare terminal. It prints a live feed.
2. `Win+Shift+S` as many times as you like — no command between captures. Each one
   auto-saves, prints a timestamped path line you can copy, and lands on your
   clipboard ready to paste:
   ```
   [15:42:01] C:\Users\you\.claude\shots\shot-20260624-154201.png
   [15:42:18] C:\Users\you\.claude\shots\shot-20260624-154218.png
   ```
3. `Ctrl+C` to stop the feed when you're done.

**Saving keepers to a vault** — promote the shots worth keeping out of the temporary
folder and into a permanent one (a notes vault, a project folder, anywhere):

1. Point `shot-save` at a destination once. It must already exist (or pass `-Create`):
   ```powershell
   shot-save-config 'C:\Users\you\Obsidian\attachments\Claude Terminal screenshots'
   # an Obsidian attachments folder is just an example — any folder works
   ```
   Run `shot-save-config` with no argument any time to see the current destination.
2. Capture shots as usual with `shot` / `shot-watch`, then move them:
   ```powershell
   shot-save all                       # move every saved shot
   shot-save shot-20260624-154201.png  # or move only the ones you name
   ```
3. `shot-save` **moves** the files (it doesn't copy), then prints two lists for the moved
   shots — their new file paths, and ready-to-paste markdown embeds:
   ```
   File paths:
   C:\Users\you\Obsidian\attachments\Claude Terminal screenshots\shot-20260624-154201.png

   Markdown embeds:
   ![](<C:\Users\you\Obsidian\attachments\Claude Terminal screenshots\shot-20260624-154201.png>)
   ```
   The embed uses the angle-bracket form so paths with spaces still render. A name that
   already exists in the destination is auto-renamed (`-1`, `-2`, …) — `shot-save` never
   overwrites a file in your vault.

### Running it from Claude Code's `!` prompt

With the optional bash shims installed (Install step 2), you can run the commands
straight from Claude Code's `!` prompt — e.g. `!shot` saves a capture and prints its
path, which Claude reads with no manual paste at all.

The `!` prompt is a **non-interactive, one-shot** shell, so a couple of commands behave
differently there than in a full terminal:

| Command            | Git Bash / PowerShell terminal | Claude Code `!` prompt |
| ------------------ | ------------------------------ | ---------------------- |
| `shot`             | ✅                             | ✅ `!shot` |
| `shot-save`        | ✅                             | ✅ `!shot-save all` |
| `shot-save-config` | ✅                             | ✅ `!shot-save-config '<path>'` |
| `shot-clear`       | ✅ (prompts y/N)               | ✅ with `-Force` — `!shot-clear -Force` (the prompt can't read input there) |
| `shot-watch`       | ✅ (live feed, Ctrl+C)         | ✋ run it in a real terminal — it's a live loop that would hang the prompt |

**Without the installer**, set up a shim by hand — drop one on your PATH:

```bash
printf '#!/usr/bin/env bash\nexec powershell.exe -sta -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/scripts/shot.ps1" "$@"\n' > ~/.local/bin/shot && chmod +x ~/.local/bin/shot
```

Or skip shims entirely: set `"defaultShell": "powershell"` in `~/.claude/settings.json`
(plus `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` on Windows) to run the `!` prompt as PowerShell —
though that switches every `!` command, not just these.

## How it works

- `shot` reads the clipboard **as an image** (`Get-Clipboard -Format Image`), saves
  it to a PNG, and replaces the clipboard with the file's path so you can paste it.
- `shot-watch` runs a live foreground loop in your terminal: it polls the clipboard
  and, whenever a **new** image appears, does the same thing automatically — saving
  the PNG, copying its path, and **printing** the path so you keep a running list of
  every capture. `Ctrl+C` stops it.
- The shots folder self-prunes to the 100 most recent captures. `shot-save` lets you move
  the ones worth keeping into a permanent folder before they're pruned.
- `shot-save` **moves** files from `~\.claude\shots` into the folder you set with
  `shot-save-config` (stored in `~\.claude\shot-save.config.json`). It only ever touches
  files matching `shot-*.png`, rejects names containing path separators or `..`, and
  auto-renames rather than overwriting an existing file in the destination.

It does **not** replace or interfere with Snipping Tool — `Win+Shift+S` works
exactly as before; this only picks up the result afterward.

## Security notes

- The watcher only ever reads the clipboard **as an image**. Copied **text**
  (passwords, API keys, tokens) returns nothing — it is never read, saved, or logged.
- Any **image** you capture while watching is written to disk as a plain PNG under
  `~\.claude\shots`. Run `shot-clear` to wipe them, and keep `shot-watch` **off**
  except during active config bursts.
- The scripts themselves do **no network activity**. Everything is local file writes.
- However keep in mind that sharing any screenshot with Claude Code transmits that image to the model — true
  of any screenshot, with or without this tool. 


## Limitations

- **Screenshots only.** Claude Code's reader handles images and PDFs, not video, so
  screen recordings (mp4/webm/gif) can't be consumed directly.
- Windows + Windows PowerShell 5.1 (STA). Not tested on PowerShell 7 / `pwsh` (which
  defaults to MTA and may need an STA shim for clipboard reads).

## Uninstall

Remove the dot-source line from your PowerShell `$PROFILE`, then delete
`~\.claude\scripts\shot*.ps1`, `~\.claude\shots`, and `~\.claude\shot-save.config.json`
(if you set a vault destination). If you installed the bash shims, also delete them from
`~/.local/bin` (`shot`, `shot-watch`, `shot-clear`, `shot-save`, `shot-save-config`).
Files already moved into your vault are left untouched.

## Contributing

Issues and pull requests are welcome — bug reports, PowerShell 7 / `pwsh` support,
or a recording-to-frames bridge are all fair game. It's a small, single-purpose tool;
keep changes focused and cross-platform-aware where it matters.

## License

MIT
