# Stealth Overlay

A lightweight Windows desktop overlay that reads on-screen content (via OCR or direct browser DOM extraction) and sends it to an AI engine to generate answers or code solutions — displayed in a floating, topmost window.

[![CI](https://github.com/Evangelion-eva/Stealth/actions/workflows/ci.yml/badge.svg)](https://github.com/Evangelion-eva/Stealth/actions/workflows/ci.yml)

---

## Features

- **OCR solve** — WinRT in-memory OCR captures screen text instantly (no external process)
- **Browser tab solve** — Direct DOM extraction from the embedded WebView2 browser (zero lag)
- **Multi-provider AI** — round-robins across Groq, Google Gemini, and OpenRouter keys
- **Force-language solve** — Java, C++, or Python with a single hotkey
- **Floating answer/code viewer** — translucent, borderless, topmost; invisible to screen-capture tools via `WDA_EXCLUDEFROMCAPTURE`
- **Settings panel** — configure providers, API keys, hotkeys, and button visibility at runtime
- **Panic kill** — single hotkey wipes all overlay windows and exits immediately

---

## Quick Start

### 1. Prerequisites

- Windows 10/11 with PowerShell 5.1+
- WebView2 Runtime (bundled in `wv2sdk/` for offline use, or install from Microsoft)
- At least one API key from a supported provider

### 2. Configure API keys

Copy the example config and fill in your keys:

```powershell
Copy-Item config.example.json config.json
notepad config.json
```

Edit the `Keys` array — replace each `YOUR_..._API_KEY_HERE` placeholder with a real key.  
**Never commit `config.json`** — it is git-ignored.

Supported providers:

| Provider | Key prefix | Get a key |
|---|---|---|
| **Groq** | `gsk_...` | https://console.groq.com |
| **Google Gemini** | `AIza...` | https://aistudio.google.com |
| **OpenRouter** | `sk-or-v1-...` | https://openrouter.ai |

### 3. Launch

**Silent background launch (recommended):**

```bat
Launch.bat
```

**With debug console:**

```bat
Launch-Console.bat
```

**Kill the running instance:**

```bat
Kill-Stealth.bat
```

---

## Hotkeys (defaults — configurable in Settings)

| Shortcut | Action |
|---|---|
| `Ctrl+Shift+T` | Auto-solve via OCR |
| `Ctrl+Shift+S` | Solve active browser tab (zero lag) |
| `Ctrl+Shift+J` | Force Java solve |
| `Ctrl+Shift+C` | Force C++ solve |
| `Ctrl+Shift+Y` | Force Python solve |
| `Ctrl+Shift+B` | Toggle stealth browser |
| `Ctrl+Shift+P` | Screenshot to clipboard |
| `Ctrl+Shift+Q` | Panic kill / exit |
| `Esc` | Dismiss answer/code overlay |

---

## File Structure

```
.
├── StealthOverlay.ps1      # Core engine — OCR, AI routing, overlay rendering
├── config.example.json     # Committed template (no real keys)
├── config.json             # Your local config — git-ignored, never committed
├── Launch.bat              # Silent launch via wscript (no console window)
├── Launch-Console.bat      # Diagnostic launch with visible console
├── Run-Stealth.vbs         # VBScript shim — starts PowerShell windowless
├── Kill-Stealth.bat        # Emergency termination
├── test_suite.html         # Offline test harness
├── wv2sdk/                 # WebView2 SDK DLLs (git-ignored)
└── .github/
    └── workflows/
        ├── ci.yml          # Syntax + secret-leak checks on every push
        └── metrics.yml     # Weekly repo traffic & stats report
```

---

## Security

- `config.json` and `keys.txt` are **git-ignored** — they never leave your machine.
- CI runs a secret-leak scan on every push (checks for Groq, Gemini, and OpenRouter key patterns).
- Logs never print API key values.
- Add providers in the `Keys` array; the engine round-robins and retries on failure.

---

## Architecture

```
Launch.bat
  └── Run-Stealth.vbs  (windowless wscript shim)
        └── powershell -WindowStyle Hidden
              └── StealthOverlay.ps1
                    ├── Config loader (config.json → SecureString in memory)
                    ├── Hotkey engine (RegisterHotKey Win32)
                    ├── OCR engine (WinRT Windows.Media.Ocr)
                    ├── Browser engine (WebView2 COM)
                    ├── AI router (Groq / Gemini / OpenRouter — modular)
                    └── Overlay renderer (Win32 layered window, WDA_EXCLUDEFROMCAPTURE)
```

Adding a new AI provider: add an entry to the `Keys` array in `config.json` with the new `Provider` name, then add a matching `Invoke-ProviderRequest` branch in `StealthOverlay.ps1`.

---

## GitHub Metrics

A `METRICS_TOKEN` repository secret is required for the weekly metrics workflow.

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens**.
2. Create a token scoped to `Evangelion-eva/Stealth` with **read** access to:
   - Repository metadata
   - Traffic (requires token owner to be a repo admin/contributor)
3. In the repository go to **Settings → Secrets and variables → Actions → New repository secret**.
4. Name it `METRICS_TOKEN`, paste the token value, save.

The workflow runs every Monday and is also triggerable manually from the **Actions** tab.

---

## License

MIT
