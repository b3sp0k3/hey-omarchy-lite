#!/bin/bash
# Uninstaller for Hey Omarchy-Lite. Reverses install.sh.
set -uo pipefail

BIN_DEST="$HOME/.local/bin/hey-omarchy-lite"
PLUGIN_DEST="$HOME/.config/omarchy/plugins/atb.heyomarchylite"
BINDINGS="$HOME/.config/hypr/bindings.lua"
SHELL_JSON="$HOME/.config/omarchy/shell.json"
MARK_START="-- >>> hey-omarchy-lite (managed) >>>"
MARK_END="-- <<< hey-omarchy-lite (managed) <<<"

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }

echo "Hey Omarchy-Lite — uninstaller"
echo

if [ -f "$BINDINGS" ] && grep -qF -- "$MARK_START" "$BINDINGS"; then
  cp "$BINDINGS" "$BINDINGS.bak-hey-omarchy-lite-uninstall-$(date +%Y%m%d-%H%M%S)"
  sed -i "/$(printf '%s' "$MARK_START" | sed 's/[.[\*^$/]/\\&/g')/,/$(printf '%s' "$MARK_END" | sed 's/[.[\*^$/]/\\&/g')/d" "$BINDINGS"
  ok "removed keybinding from $BINDINGS"
fi

if [ -f "$SHELL_JSON" ] && grep -q 'atb.heyomarchylite' "$SHELL_JSON"; then
  cp "$SHELL_JSON" "$SHELL_JSON.bak-hey-omarchy-lite-uninstall"
  python3 - "$SHELL_JSON" <<'PYEOF'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
removed = 0
for section in data.get("bar", {}).get("layout", {}).values():
    if isinstance(section, list):
        before = len(section)
        section[:] = [w for w in section
                      if not (isinstance(w, dict) and w.get("id") == "atb.heyomarchylite")]
        removed += before - len(section)
if removed:
    json.dump(data, open(path, "w"), indent=2)
    print(f"   took the widget off the bar ({removed} entry)")
PYEOF
fi

rm -rf "$PLUGIN_DEST"
ok "removed $PLUGIN_DEST"

rm -f "$BIN_DEST"
ok "removed $BIN_DEST"

rm -rf "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hey-omarchy-lite"
rm -rf "$HOME/.local/state/hey-omarchy-lite"
ok "removed runtime/state directories"

hyprctl reload >/dev/null 2>&1 || true
ok "reloaded Hyprland"

echo
echo "Hey Omarchy-Lite removed."
