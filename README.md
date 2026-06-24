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

Requires Windows PowerShell 5.1+ (ships with Windows). From a PowerShell prompt:

```powershell
git clone https://github.com/ajthilakan/win-screenshot-for-claude.git
cd win-screenshot-for-claude
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer copies the scripts to `~\.claude\scripts`, creates `~\.claude\shots`,
and adds one line to your PowerShell `$PROFILE` so the commands load in every
terminal. Open a new terminal afterward.

## Usage

```powershell
shot               # capture clipboard image -> PNG, copy its path to the clipboard
shot-watch         # live feed: prints + copies the path for every capture (Ctrl+C to stop)
shot-clear         # delete all saved screenshots (prompts; -Force to skip)
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

Tip: once installed, you can run `shot` straight from the Claude Code prompt with
`!shot` — Claude sees the printed path in the command output and reads the image
for you, no manual paste at all.

## How it works

- `shot` reads the clipboard **as an image** (`Get-Clipboard -Format Image`), saves
  it to a PNG, and replaces the clipboard with the file's path so you can paste it.
- `shot-watch` runs a live foreground loop in your terminal: it polls the clipboard
  and, whenever a **new** image appears, does the same thing automatically — saving
  the PNG, copying its path, and **printing** the path so you keep a running list of
  every capture. `Ctrl+C` stops it.
- The shots folder self-prunes to the 100 most recent captures.

It does **not** replace or interfere with Snipping Tool — `Win+Shift+S` works
exactly as before; this only picks up the result afterward.

## Security notes

- The watcher only ever reads the clipboard **as an image**. Copied **text**
  (passwords, API keys, tokens) returns nothing — it is never read, saved, or logged.
- Any **image** you capture while watching is written to disk as a plain PNG under
  `~\.claude\shots`. Run `shot-clear` to wipe them, and keep `shot-watch` **off**
  except during active config bursts.
- Sharing any screenshot with Claude Code transmits that image to the model — true
  of any screenshot, with or without this tool.
- The scripts do **no network activity**. Everything is local file writes.

## Limitations

- **Screenshots only.** Claude Code's reader handles images and PDFs, not video, so
  screen recordings (mp4/webm/gif) can't be consumed directly.
- Windows + Windows PowerShell 5.1 (STA). Not tested on PowerShell 7 / `pwsh` (which
  defaults to MTA and may need an STA shim for clipboard reads).

## Uninstall

Remove the dot-source line from your PowerShell `$PROFILE`, then delete
`~\.claude\scripts\shot-*.ps1` and `~\.claude\shots`.

## License

MIT
