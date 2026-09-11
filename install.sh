#!/bin/bash
# Installer for Hey Omarchy-Lite. Safe to re-run.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$HOME/.local/bin/hey-omarchy-lite"
PLUGIN_ID="io.github.b3sp0k3.hey-omarchy-lite"
PLUGIN_DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
LEGACY_PLUGIN_DEST="$HOME/.config/omarchy/plugins/atb.heyomarchylite"
BINDINGS="$HOME/.config/hypr/bindings.lua"
MARK_START="-- >>> hey-omarchy-lite (managed) >>>"
MARK_END="-- <<< hey-omarchy-lite (managed) <<<"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; }

echo "Hey Omarchy-Lite — installer"
echo

echo "Checking requirements..."
missing_hard=0

if command -v hyprctl >/dev/null 2>&1 && command -v omarchy >/dev/null 2>&1; then
  ok "Omarchy / Hyprland"
else
  fail "Omarchy / Hyprland not found — this only runs on an Omarchy system"
  missing_hard=1
fi

if command -v pw-record >/dev/null 2>&1; then
  ok "pw-record (pipewire-audio)"
else
  fail "pw-record not found — install pipewire-audio"
  missing_hard=1
fi

if command -v ollama >/dev/null 2>&1; then
  ok "ollama"
  if ollama list 2>/dev/null | grep -q '^qwen2.5:3b'; then
    ok "qwen2.5:3b model"
  else
    warn "qwen2.5:3b not pulled yet — run: ollama pull qwen2.5:3b"
  fi
else
  fail "ollama not found — install it and pull qwen2.5:3b (https://ollama.com)"
  missing_hard=1
fi

if command -v voxtype >/dev/null 2>&1 || command -v whisper-cli >/dev/null 2>&1; then
  ok "speech-to-text (voxtype or whisper-cli)"
else
  fail "no STT engine found — install voxtype or whisper-cpp"
  missing_hard=1
fi

if command -v piper-tts >/dev/null 2>&1; then
  ok "piper-tts"
  if [ -f "$HOME/.local/share/piper/en_US-ryan-high.onnx" ] || [ -f "$HOME/.local/share/piper/en_GB-northern_english_male-medium.onnx" ]; then
    ok "a piper voice model"
  else
    warn "piper-tts installed but no voice model found under ~/.local/share/piper/ — falls back to espeak-ng"
  fi
elif command -v espeak-ng >/dev/null 2>&1; then
  warn "piper-tts not found, will use espeak-ng (lower quality speech)"
else
  fail "no TTS engine found — install piper-tts or espeak-ng"
  missing_hard=1
fi

if command -v omarchy-voice >/dev/null 2>&1; then
  ok "omarchy-voice (enables desktop-action routing)"
else
  warn "omarchy-voice not found — Hey Omarchy-Lite will still answer questions," \
       "but can't run desktop actions (open/close apps, windows, etc). See:" \
       "https://github.com/wombatoperator/omarchy-voice"
fi

if [ "$missing_hard" = "1" ]; then
  echo
  fail "missing required dependencies above — install them and re-run"
  exit 1
fi

echo
echo "Installing..."

mkdir -p "$HOME/.local/bin"
cp "$REPO_ROOT/bin/hey-omarchy-lite" "$BIN_DEST"
chmod +x "$BIN_DEST"
ok "installed $BIN_DEST"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) warn "$HOME/.local/bin is not on your PATH — add it to your shell profile" ;;
esac

# Install bar widget — marketplace-compliant: manifest at repo root
mkdir -p "$(dirname "$PLUGIN_DEST")"
rm -rf "$PLUGIN_DEST"
mkdir -p "$PLUGIN_DEST"
# Prefer repo-root manifest (marketplace layout), fallback to plugin subfolder
if [ -f "$REPO_ROOT/manifest.json" ] && [ -f "$REPO_ROOT/HeyOmarchyLiteIndicator.qml" ]; then
  cp "$REPO_ROOT/manifest.json" "$PLUGIN_DEST/manifest.json"
  cp "$REPO_ROOT/HeyOmarchyLiteIndicator.qml" "$PLUGIN_DEST/HeyOmarchyLiteIndicator.qml"
elif [ -d "$REPO_ROOT/plugin/io.github.b3sp0k3.hey-omarchy-lite" ]; then
  cp -r "$REPO_ROOT/plugin/io.github.b3sp0k3.hey-omarchy-lite"/* "$PLUGIN_DEST"/
elif [ -d "$REPO_ROOT/plugin/atb.heyomarchylite" ]; then
  cp -r "$REPO_ROOT/plugin/atb.heyomarchylite"/* "$PLUGIN_DEST"/
  # patch legacy manifest ID if needed
  python3 -c "import json,pathlib; p=pathlib.Path('$PLUGIN_DEST/manifest.json'); m=json.load(open(p)); m['id']='$PLUGIN_ID'; m['author']='b3sp0k3'; m['license']='MIT'; json.dump(m, open(p,'w'), indent=2)" 2>/dev/null || true
fi
# Ensure moduleName matches new ID (in case sourced from legacy)
if [ -f "$PLUGIN_DEST/HeyOmarchyLiteIndicator.qml" ]; then
  sed -i 's/moduleName: "atb.heyomarchylite"/moduleName: "io.github.b3sp0k3.hey-omarchy-lite"/g' "$PLUGIN_DEST/HeyOmarchyLiteIndicator.qml" 2>/dev/null || true
  sed -i 's/moduleName: "atb\.heyomarchylite"/moduleName: "io.github.b3sp0k3.hey-omarchy-lite"/g' "$PLUGIN_DEST/HeyOmarchyLiteIndicator.qml" 2>/dev/null || true
fi
ok "installed bar widget to $PLUGIN_DEST"

# Migrate away from legacy ID if present
if [ -d "$LEGACY_PLUGIN_DEST" ] && [ "$LEGACY_PLUGIN_DEST" != "$PLUGIN_DEST" ]; then
  rm -rf "$LEGACY_PLUGIN_DEST"
  ok "removed legacy plugin $LEGACY_PLUGIN_DEST"
  # Remove legacy entry from bar layout
  SHELL_JSON="$HOME/.config/omarchy/shell.json"
  if [ -f "$SHELL_JSON" ] && grep -q 'atb.heyomarchylite' "$SHELL_JSON"; then
    cp "$SHELL_JSON" "$SHELL_JSON.bak-migrate-heyomarchylite-$(date +%s)" 2>/dev/null || true
    python3 - "$SHELL_JSON" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
    removed = 0
    for section in data.get("bar", {}).get("layout", {}).values():
        if isinstance(section, list):
            before = len(section)
            section[:] = [w for w in section if not (isinstance(w, dict) and w.get("id") == "atb.heyomarchylite")]
            removed += before - len(section)
    if removed:
        json.dump(data, open(path, "w"), indent=2)
        print(f"   migrated bar layout: removed {removed} legacy entry")
except Exception as e:
    print(f"   warn: could not migrate shell.json: {e}", file=sys.stderr)
PYEOF
  fi
fi

if command -v omarchy >/dev/null 2>&1; then
  if omarchy plugin validate "$PLUGIN_DEST" >/dev/null 2>&1; then
    ok "plugin validated"
  else
    warn "plugin failed omarchy's validator — bar widget may not load"
  fi
  # Ensure bar contains new ID (omarchy bar put is idempotent)
  if omarchy bar put "$PLUGIN_ID" --section right >/dev/null 2>&1; then
    ok "added to bar (right section)"
  else
    warn "could not add to bar automatically — run manually:" \
         "omarchy bar put $PLUGIN_ID --section right"
  fi
fi

if [ -f "$BINDINGS" ] && grep -qF -- "$MARK_START" "$BINDINGS"; then
  ok "keybinding already present in $BINDINGS"
else
  mkdir -p "$(dirname "$BINDINGS")"
  touch "$BINDINGS"
  cp "$BINDINGS" "$BINDINGS.bak-hey-omarchy-lite-$(date +%Y%m%d-%H%M%S)"
  {
    echo ""
    echo "$MARK_START"
    echo "-- Hey Omarchy-Lite: local, free voice assistant. Press CONTROL+SPACE to"
    echo "-- toggle listening. https://github.com/b3sp0k3/hey-omarchy-lite"
    echo 'if o.cmd_present("hey-omarchy-lite") then'
    echo '  o.bind("CONTROL + SPACE", "Hey Omarchy-Lite voice assistant (toggle)", "hey-omarchy-lite toggle")'
    echo "end"
    echo "$MARK_END"
  } >> "$BINDINGS"
  ok "added CONTROL+SPACE keybinding (backed up bindings.lua first)"
fi

hyprctl reload >/dev/null 2>&1 || true
ok "reloaded Hyprland"

echo
echo "Done. Press CONTROL+SPACE to start listening, press it again to stop."
echo "Doctor check: hey-omarchy-lite toggle   (or click the icon on your bar)"
echo "Marketplace: omarchy plugin add https://github.com/b3sp0k3/hey-omarchy-lite.git --enable"
