# Hey Omarchy-Lite

Hey Omarchy-Lite is a local, free, and fully open-source voice assistant for [Omarchy](https://omarchy.org) (Hyprland). One hotkey (`CONTROL + SPACE`) handles everything — simple desktop actions run instantly, complex ones fall back to `omarchy-voice`'s full agent, and plain questions get a fast local answer. No cloud APIs, no API keys, nothing leaves your machine.

```
you   "close the browser"
      → resolves to whatever browser is actually open, closes it instantly
you   "what's the tallest mountain in the world"
      → answered directly in a couple of seconds
you   "open my email and put it beside the browser"
      → too novel for the instant path, so it's handed to a full local
        agent that can actually reason through it (slower, still free)
```

## Why this exists

[omarchy-voice](https://github.com/wombatoperator/omarchy-voice) is a
full desktop-control voice agent for Omarchy — it can move windows, run
terminal commands, click things, search the web. It's genuinely capable,
but every request that isn't one of its ~20 hardcoded instant patterns
sends its *entire* tool manifest (thousands of tokens) to the model, which
on a CPU-only machine can take **two minutes** — even for a plain question
like "what's 2+2".

Hey Omarchy-Lite exists to make the common case (asking something, or a
simple desktop action) fast, while still being able to fall back to
omarchy-voice's real agent for anything that genuinely needs it.

## How it works

```
mic (pw-record) → speech-to-text (voxtype / whisper.cpp)
                          │
                          ▼
              ┌─────────────────────────┐
              │  known action?          │  regex fastpath (no LLM, <10ms)
              │  (open/close app,       │  reused directly from omarchy-voice
              │  workspace, window,     │
              │  mouse, volume, ...)    │
              └────────────┬────────────┘
                     yes │      │ no
                          ▼      ▼
                     instant   cheap local classification call (~1-2s)
                     action    (ACTION or QUESTION?)
                                    │           │
                              ACTION│           │QUESTION
                                    ▼           ▼
                     omarchy-voice's full   direct minimal-prompt
                     agent (~2min, but      Ollama chat (~2-8s,
                     can do anything)       no tools/manifest)
                          │                       │
                          └───────────┬───────────┘
                                      ▼
                              piper (text-to-speech)
```

Three routes, one hotkey — the routing decision is what keeps plain
questions fast without giving up the ability to actually do things.

## Requirements

- [Omarchy](https://omarchy.org) (Hyprland-based)
- [Ollama](https://ollama.com) with `qwen2.5:3b` pulled (`ollama pull qwen2.5:3b`)
- `pipewire-audio` (for `pw-record`)
- A speech-to-text engine: [voxtype](https://github.com/omarchy-linux/voxtype)
  (ships with Omarchy) or `whisper-cpp`
- A text-to-speech engine: `piper-tts` (with a voice model under
  `~/.local/share/piper/`) or `espeak-ng` as a lower-quality fallback
- [omarchy-voice](https://github.com/wombatoperator/omarchy-voice) —
  **optional but recommended**. Without it, Hey Omarchy-Lite still answers
  questions, but can't run desktop actions at all (no fastpath, no full-agent
  fallback) — it's what actually does the "open/close app, move window,
  control the OS" side of things.

`./install.sh` checks all of this and tells you what's missing.

## Install

```bash
git clone https://github.com/b3sp0k3/hey-omarchy-lite
cd hey-omarchy-lite
./install.sh
```

Safe to re-run. It backs up `~/.config/hypr/bindings.lua` before touching
it, and only ever adds/updates its own clearly-marked block there.

## Uninstall

```bash
./uninstall.sh
```

Reverses everything install.sh did: removes the keybinding, the bar
widget, the binary, and its runtime/state directories.

## Use

- `CONTROL + SPACE` — start listening; press again to stop and act
- Click the bar icon — same thing, for people who'd rather not remember a
  hotkey. Icon reflects live state (listening / thinking / acting / idle)
- `hey-omarchy-lite toggle` — what both of the above actually call

## Known limitations

- **Timings are hardware-dependent.** All numbers above were measured on
  a CPU-only Haswell-era machine with no GPU acceleration. A machine with a
  real GPU or a newer CPU will be faster across the board; the *shape* of
  the routing (instant / cheap-classify / full-agent) stays the same
  regardless.
- **The intent classifier is a 3B model doing binary classification** — it's
  been tested and is reliable on a reasonable range of phrasings (few-shot
  examples in the prompt made a real difference here), but it isn't
  perfect. A misclassified question costs a ~2 minute wait instead of a
  few seconds; a misclassified action just gets talked about instead of
  done. Neither breaks anything.
- **Desktop-action routing requires omarchy-voice.** Its `fastpath` module
  and `say` command are what actually resolve and execute actions.

## Credits

Built on top of [omarchy-voice](https://github.com/wombatoperator/omarchy-voice)'s
`fastpath` regex matcher and full agent (`omarchy-voice say`) — this
project doesn't reimplement desktop-control logic, it adds a fast routing
layer in front of it.

## License

MIT — see [LICENSE](LICENSE).
