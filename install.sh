#!/bin/bash
# Installer for Hey Omarchy-Lite. Safe to re-run.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DEST="$HOME/.local/bin/hey-omarchy-lite"
PLUGIN_DEST="$HOME/.config/omarchy/plugins/atb.heyomarchylite"
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

mkdir -p "$(dirname "$PLUGIN_DEST")"
rm -rf "$PLUGIN_DEST"
cp -r "$REPO_ROOT/plugin/atb.heyomarchylite" "$PLUGIN_DEST"
ok "installed bar widget to $PLUGIN_DEST"

if command -v omarchy >/dev/null 2>&1; then
  if omarchy plugin validate "$PLUGIN_DEST" >/dev/null 2>&1; then
    ok "plugin validated"
  else
    warn "plugin failed omarchy's validator — bar widget may not load"
  fi
  if omarchy bar put atb.heyomarchylite --section right >/dev/null 2>&1; then
    ok "added to bar (right section)"
  else
    warn "could not add to bar automatically — run manually:" \
         "omarchy bar put atb.heyomarchylite --section right"
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
    echo "-- toggle listening. https://github.com/atb/hey-omarchy-lite"
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
