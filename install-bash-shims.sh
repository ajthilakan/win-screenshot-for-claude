#!/usr/bin/env bash
# install-bash-shims.sh — make the shot commands callable from Git Bash, and from
# Claude Code's `!` prompt (which defaults to Git Bash on Windows).
#
# These shims are thin wrappers that call the PowerShell entry points installed by
# install.ps1 — so run install.ps1 FIRST. This step is OPTIONAL: you only need it if
# you want to drive the tool from Git Bash rather than a PowerShell terminal.
#
# Idempotent and safe to re-run. A shim is created for every command entry point in
# ~/.claude/scripts (any new command added later is picked up automatically).
set -euo pipefail

# Where install.ps1 placed the PowerShell entry points.
scripts_dir="$HOME/.claude/scripts"

if [ ! -f "$scripts_dir/shot.ps1" ]; then
  echo "error: $scripts_dir/shot.ps1 not found." >&2
  echo "Run the PowerShell installer first, from this repo:" >&2
  echo "  powershell -ExecutionPolicy Bypass -File ./install.ps1" >&2
  exit 1
fi

# Put the shims in a directory that is on Git for Windows' default PATH.
bin_dir="$HOME/.local/bin"
mkdir -p "$bin_dir"

made=0
for ps1 in "$scripts_dir"/*.ps1; do
  base="$(basename "$ps1" .ps1)"
  # shot-tools.ps1 is the shared library, not a command — skip it.
  if [ "$base" = "shot-tools" ]; then
    continue
  fi
  shim="$bin_dir/$base"
  # $USERPROFILE and "$@" are LITERAL on purpose — they resolve when the shim RUNS,
  # not now. powershell.exe reads $USERPROFILE (a Windows env var) and accepts the
  # forward-slash path. Writing from bash keeps the file LF + BOM-free.
  printf '#!/usr/bin/env bash\nexec powershell.exe -sta -NoProfile -ExecutionPolicy Bypass -File "$USERPROFILE/.claude/scripts/%s.ps1" "$@"\n' "$base" > "$shim"
  chmod +x "$shim"
  echo "  installed shim: $shim"
  made=$((made + 1))
done

echo ""
echo "Done — created $made shim(s) in $bin_dir."

# The shims are useless until their directory is on PATH.
case ":$PATH:" in
  *":$bin_dir:"*) : ;;
  *)
    echo ""
    echo "note: $bin_dir is not on your PATH yet. Add it (e.g. in ~/.bashrc):"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac

cat <<'EOF'

You can now run shot / shot-watch / shot-clear / shot-save / shot-save-config from Git Bash.

From Claude Code's `!` prompt specifically (a non-interactive, one-shot shell), note:
  - shot         works great:           !shot
  - shot-save    works:                 !shot-save all
  - shot-clear   needs -Force:          !shot-clear -Force   (the y/N prompt can't read input there)
  - shot-watch   use a real terminal, NOT the ! prompt — it's a live loop that would hang it
EOF
