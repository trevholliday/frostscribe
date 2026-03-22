# Frostscribe — Architecture & Design Document

> A native macOS tool for ripping and preserving physical disc media to a local Jellyfin, Plex, or Kodi library.
> Built in Swift. Designed for Mac homelab servers.

---

## Table of Contents

1. [Vision](#vision)
2. [What Frostscribe Is Not](#what-frostscribe-is-not)
3. [System Overview](#system-overview)
4. [Package Structure](#package-structure)
5. [Component Breakdown](#component-breakdown)
   - [FrostscribeCore](#frostscribecore)
   - [FrostscribeCLI](#frostscribecli)
   - [FrostscribeUI](#frostscribeui)
   - [FrostscribeWorker](#frostscribeworker)
6. [Configuration](#configuration)
7. [Data Flow](#data-flow)
8. [State Files](#state-files)
9. [Media Server Output Formats](#media-server-output-formats)
10. [Worker Lifecycle](#worker-lifecycle)
11. [Vigil Mode](#vigil-mode)
12. [TMDB Integration](#tmdb-integration)
12. [CLI Command Reference](#cli-command-reference)
13. [Dependencies](#dependencies)
14. [Build & Distribution](#build--distribution)
15. [Versioning Strategy](#versioning-strategy)
16. [Out of Scope for v1](#out-of-scope-for-v1)

---

## Vision

Frostscribe is a native macOS application that acts as a digital librarian — taking physical disc media (Blu-ray, DVD) and permanently preserving it in a local media library. Like the monks of a scriptorium transcribing manuscripts from one medium to another, Frostscribe carefully identifies, rips, encodes, and catalogs each disc into a format that Jellyfin, Plex, or Kodi can immediately recognize and serve.

The name comes from three ideas:
- **Frost** — cold, permanent, preserved storage (Frostbyte)
- **Scribe** — the monk who transcribes from one medium to another
- **Frostscribe** — a tool that permanently transcribes your physical media into your digital cold storage

By default, Frostscribe is an interactive tool designed for a person who is sitting at their homelab, swapping discs, and building their library intentionally. For advanced users who want fully automatic ripping, **Vigil Mode** can be enabled — see the Vigil Mode section.

---

## What Frostscribe Is Not

- **Not a Docker container** — Docker on macOS cannot reliably access optical drives. Frostscribe runs natively and accesses the disc directly.
- **Not automatic by default** — The default experience is interactive. You insert a disc and run `frostscribe rip`. Vigil Mode enables automatic disc detection for users who explicitly opt in.
- **Not a media server** — Frostscribe produces files. Jellyfin, Plex, or Kodi serve them.
- **Not cross-platform in v1** — macOS only. Linux and Windows support may come later based on demand.
- **Not a MakeMKV replacement** — Frostscribe wraps `makemkvcon` CLI. MakeMKV must be installed separately.

---

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        User                                  │
│                         │                                    │
│          ┌──────────────┼──────────────┐                    │
│          ▼              ▼              ▼                    │
│   frostscribe CLI   Menu Bar App   frostscribe worker        │
│   (interactive)     (monitor)      (launchd agent)           │
│          │              │              │                    │
│          └──────────────┼──────────────┘                    │
│                         ▼                                    │
│                  FrostscribeCore                             │
│          ┌──────────────┼──────────────┐                    │
│          ▼              ▼              ▼                    │
│      MakeMKV        HandBrake        TMDB                   │
│      (ripping)      (encoding)    (metadata)                │
│          │              │                                    │
│          ▼              ▼                                    │
│      status.json    queue.json                               │
│          │              │                                    │
│          ▼              ▼                                    │
│         NAS / Local Media Library                            │
│    (Jellyfin / Plex / Kodi format)                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Package Structure

Frostscribe is organized as a Swift Package with multiple targets sharing a single core library.

```
Frostscribe/
├── Package.swift
├── ARCHITECTURE.md
├── README.md
├── .gitignore
│
├── Sources/
│   ├── FrostscribeCore/         ← shared business logic (no UI, no CLI)
│   │   ├── Config/
│   │   │   ├── Config.swift
│   │   │   └── MediaServer.swift
│   │   ├── Models/
│   │   │   ├── RipJob.swift
│   │   │   ├── EncodeJob.swift
│   │   │   └── DiscTitle.swift
│   │   ├── Services/
│   │   │   ├── StatusManager.swift
│   │   │   ├── QueueManager.swift
│   │   │   ├── NotificationService.swift
│   │   │   └── TMDBClient.swift
│   │   ├── Ripping/
│   │   │   ├── MakeMKVRunner.swift
│   │   │   ├── MakeMKVParser.swift
│   │   │   └── DiscEjector.swift
│   │   ├── Encoding/
│   │   │   ├── HandBrakeRunner.swift
│   │   │   └── EncoderPreset.swift
│   │   └── Output/
│   │       └── PathBuilder.swift
│   │
│   ├── FrostscribeCLI/          ← command line tool
│   │   ├── main.swift
│   │   ├── Commands/
│   │   │   ├── RipCommand.swift
│   │   │   ├── StatusCommand.swift
│   │   │   ├── QueueCommand.swift
│   │   │   └── WorkerCommand.swift
│   │   └── Display/
│   │       ├── Colors.swift
│   │       ├── ProgressBar.swift
│   │       └── Banners.swift
│   │
│   ├── FrostscribeUI/           ← SwiftUI menu bar app
│   │   ├── FrostscribeApp.swift
│   │   ├── MenuBarView.swift
│   │   ├── Views/
│   │   │   ├── StatusView.swift
│   │   │   ├── QueueView.swift
│   │   │   └── SettingsView.swift
│   │   └── ViewModels/
│   │       ├── StatusViewModel.swift
│   │       └── QueueViewModel.swift
│   │
│   └── FrostscribeWorker/       ← launchd encode worker daemon
│       └── main.swift
│
└── Tests/
    └── FrostscribeCoreTests/
        ├── MakeMKVParserTests.swift
        ├── PathBuilderTests.swift
        └── QueueManagerTests.swift
```

---

## Component Breakdown

### FrostscribeCore

The heart of the application. Contains all business logic with zero UI dependencies. Both the CLI, the menu bar app, and the worker import this package.

**Config/**
- `Config.swift` — the main configuration struct. Loaded from and saved to `~/Library/Application Support/Frostscribe/config.json`. Contains all user settings. Provides sensible defaults so the tool works out of the box after setting required fields.
- `MediaServer.swift` — enum defining supported media servers (`jellyfin`, `plex`, `kodi`) and their output path formatting rules.

**Models/**
- `RipJob.swift` — represents an active or completed rip operation. Written to `status.json` during ripping.
- `EncodeJob.swift` — represents a single entry in the encode queue (`queue.json`). Has states: `pending`, `encoding`, `done`, `error`.
- `DiscTitle.swift` — represents a single title found on a disc during the MakeMKV scan phase. Contains title number, duration, chapter count, file size, and filename.

**Services/**
- `StatusManager.swift` — atomic read/write of `status.json`. Maintains history of completed jobs (last 20). Both the rip flow and worker update this file; it is written atomically using a temp file + rename to prevent corruption.
- `QueueManager.swift` — atomic read/write of `queue.json`. Provides methods to add jobs, update progress, mark complete, and read active jobs. Uses file locking to prevent the CLI and worker from writing simultaneously.
- `NotificationService.swift` — sends macOS native notifications (via `UserNotifications` framework) when a rip or encode completes. Does not require Home Assistant or any external service.
- `TMDBClient.swift` — HTTP client for TMDB API v3. Performs multi-search (auto-detects movie vs TV), fetches season episode counts. Requires a TMDB API key in config. Gracefully no-ops if key is not set.

**Ripping/**
- `MakeMKVRunner.swift` — spawns `makemkvcon` as a child process, captures output via a pipe, and streams it line by line to the parser. Handles both the `info` (disc scan) and `mkv` (rip) modes.
- `MakeMKVParser.swift` — pure parsing logic with no I/O. Takes raw output lines from makemkvcon and produces structured data: `CINFO` → disc metadata, `TINFO` → title metadata, `MSG` → user-facing messages, `PRGV` → progress values. Fully unit tested.
- `DiscEjector.swift` — wraps `drutil eject` with a retry loop (5 attempts, 2 second delay). Reports failure clearly if all attempts fail.

**Encoding/**
- `HandBrakeRunner.swift` — spawns `HandBrakeCLI` as a child process, streams progress output, and updates the queue file in real time. Uses VideoToolbox hardware encoding (vt_h265) on Apple Silicon and Intel Macs.
- `EncoderPreset.swift` — builds the HandBrakeCLI argument list based on disc type (Blu-ray → 4K preset, DVD → 1080p preset) and audio configuration (dual track: AAC Stereo + AC3 Surround for maximum device compatibility).

**Output/**
- `PathBuilder.swift` — constructs the output file path for a given title based on the configured media server format. Takes a title, year, media type, season, episode, and returns the correct directory structure and filename. Fully unit tested.

---

### FrostscribeCLI

The interactive command line tool. Imports `FrostscribeCore` for all business logic. Contains only presentation and user interaction code.

**Entry point:** `main.swift` — uses `ArgumentParser` to dispatch subcommands.

**Commands/**
- `RipCommand.swift` — the primary interactive flow. Scans the disc, presents titles, queries TMDB, prompts user for confirmation, rips the selected title, and adds it to the encode queue.
- `StatusCommand.swift` — reads `status.json` and `queue.json` and prints a formatted summary to the terminal. This replaces the `rip-status` Rust tool.
- `QueueCommand.swift` — displays the encode queue with progress bars.
- `WorkerCommand.swift` — manages the launchd encode worker agent. Subcommands: `start`, `stop`, `restart`, `status`.

**Display/**
- `Colors.swift` — ANSI escape codes for terminal coloring. Detects color support and falls back gracefully.
- `ProgressBar.swift` — renders an ASCII progress bar with spinner for rip and encode progress.
- `Banners.swift` — ASCII art banners for the main screen and rip-again prompt.

---

### FrostscribeUI

A macOS SwiftUI menu bar application. Lives in the menu bar permanently, showing at a glance whether a rip or encode is in progress.

**FrostscribeApp.swift** — app entry point. `@main` struct. Configures the menu bar extra using `MenuBarExtra`. Polls `status.json` and `queue.json` on a timer (every 3 seconds) and updates the UI.

**MenuBarView.swift** — the popover that appears when the user clicks the menu bar icon. Shows:
- Current rip status and progress
- Current encode status and progress
- Number of jobs in queue
- Quick links to open settings

**Views/**
- `StatusView.swift` — displays current rip job with progress bar
- `QueueView.swift` — displays encode queue with per-job progress
- `SettingsView.swift` — form for editing `config.json`. Fields for: output directory, TMDB API key, media server selection, MakeMKV key, HandBrake bin path.

**ViewModels/**
- `StatusViewModel.swift` — `@Observable` class that reads `status.json` on a timer and publishes changes to the view.
- `QueueViewModel.swift` — `@Observable` class that reads `queue.json` on a timer and publishes changes.

---

### FrostscribeWorker

A minimal executable that runs as a launchd agent. Imports `FrostscribeCore` for all encoding logic.

**main.swift** — starts the encode worker loop. Polls `queue.json` every 5 seconds for pending jobs. Encodes one job at a time using `HandBrakeRunner`. Updates progress in real time. Sends a native macOS notification on completion. Handles `SIGTERM` gracefully — waits for the current encode to finish before exiting.

The worker is installed to `~/Library/LaunchAgents/com.frostscribe.worker.plist` by `frostscribe worker start` and loaded immediately via `launchctl load`. It starts automatically on login thereafter.

---

## Configuration

**Location:** `~/Library/Application Support/Frostscribe/config.json`

**Created:** automatically on first run of `frostscribe rip` or first launch of the menu bar app, via a setup wizard.

**Structure:**

```json
{
  "media_server": "jellyfin",
  "movies_dir": "/Volumes/Media/Movies",
  "tv_dir": "/Volumes/Media/TV Shows",
  "temp_dir": "/Volumes/Media/Ripping/queue",
  "tmdb_api_key": "",
  "makemkv_key": "",
  "makemkv_bin": "",
  "handbrake_bin": "",
  "notifications_enabled": true
}
```

**Fields:**

| Field | Required | Description |
|---|---|---|
| `media_server` | Yes | `jellyfin`, `plex`, or `kodi` |
| `movies_dir` | Yes | Root directory for movie output |
| `tv_dir` | Yes | Root directory for TV show output |
| `temp_dir` | Yes | Staging area for raw ripped MKV files before encoding |
| `tmdb_api_key` | No | TMDB API v4 Bearer token. Tool works without it but requires manual title entry |
| `makemkv_key` | No | MakeMKV registration key. Without it MakeMKV runs in trial mode (30 day limit) |
| `makemkv_bin` | No | Full path to `makemkvcon`. If empty, searches `$PATH` |
| `handbrake_bin` | No | Full path to `HandBrakeCLI`. If empty, searches `$PATH` |
| `notifications_enabled` | No | Whether to send native macOS notifications on job completion. Defaults to `true` |
| `vigil_mode` | No | Enables automatic disc detection and ripping. Disabled by default. Requires the menu bar app to be running. |

---

## Data Flow

### Rip Flow

```
User runs: frostscribe rip
    │
    ▼
MakeMKVRunner.scanDisc()
    → runs: makemkvcon -r info disc:0
    → MakeMKVParser parses CINFO, TINFO lines
    → returns: [DiscTitle], disc_type, disc_name
    │
    ▼
TMDBClient.pick(discName)
    → searches TMDB multi endpoint
    → presents numbered list of results + "0. Enter manually" option
    → picking a number starts immediately — no second confirmation
    → picking 0 prompts for manual title/year entry
    → returns: title, year, mediaType, tmdbId
    │
    ▼
User selects title number to rip
    │
    ▼
PathBuilder.outputPath(title, year, mediaType, mediaServer)
    → returns: correct output path for configured media server
    │
    ▼
StatusManager.write(.ripping, job)
    │
    ▼
MakeMKVRunner.rip(titleNum, destDir)
    → runs: makemkvcon -r mkv disc:0 <n> <dir>
    → streams progress via pipe
    → falls back to disk-size polling if PRGV lines absent
    → updates status.json every 1 second
    │
    ▼
DiscEjector.eject()
    → retries up to 5 times
    │
    ▼
QueueManager.add(inputPath, outputPath, preset, title)
    → appends pending job to queue.json
    │
    ▼
StatusManager.write(.idle)
    │
    ▼
User prompted: rip another disc?
```

### Encode Flow (Worker)

```
FrostscribeWorker polls queue.json every 5 seconds
    │
    ▼
Finds first job with status == "pending"
    │
    ▼
QueueManager.updateStatus(id, .encoding)
    │
    ▼
HandBrakeRunner.encode(job)
    → runs: HandBrakeCLI with vt_h265 preset
    → streams progress line by line
    → QueueManager.updateProgress(id, pct) every update
    │
    ▼
On success:
    → QueueManager.updateStatus(id, .done)
    → deletes raw MKV from temp_dir
    → removes empty parent directory
    → NotificationService.send("Encode Complete", title)
    │
    ▼
On failure:
    → QueueManager.updateStatus(id, .error)
    → NotificationService.send("Encode Failed", title)
    │
    ▼
Loop continues
```

---

## State Files

Both files live at `~/Library/Application Support/Frostscribe/`.

### status.json

Written by the rip flow. Read by the CLI status command, the menu bar app, and the web monitor (if used).

```json
{
  "status": "ripping",
  "updated_at": "2026-03-21T21:27:57Z",
  "current_job": {
    "type": "movie",
    "title": "The Dark Knight (2008)",
    "started_at": "2026-03-21T21:27:57Z",
    "phase": "ripping",
    "progress": "47%"
  },
  "history": [
    {
      "type": "movie",
      "title": "Inception (2010)",
      "started_at": "2026-03-21T20:00:00Z",
      "phase": "ripping",
      "progress": "100%",
      "completed_at": "2026-03-21T20:18:00Z"
    }
  ]
}
```

### queue.json

Written by the rip flow (adds jobs) and the worker (updates progress/status).

```json
{
  "jobs": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "encoding",
      "title": "The Dark Knight (2008)",
      "episode": null,
      "input": "/Volumes/Media/Ripping/queue/The Dark Knight (2008)/t01.mkv",
      "output": "/Volumes/Media/Movies/The Dark Knight (2008)/The Dark Knight (2008).mkv",
      "preset": "H.265 MKV 2160p60 4K",
      "progress": "62.4%",
      "added_at": "2026-03-21T21:45:00Z",
      "started_at": "2026-03-21T21:46:00Z",
      "completed_at": null
    }
  ]
}
```

Both files are written atomically: data is written to a `.tmp` file first, then renamed to the final path. `rename()` is atomic on the same filesystem volume, preventing corrupt reads if the process is killed mid-write.

---

## Media Server Output Formats

`PathBuilder` constructs paths based on the `media_server` setting in config.

### Jellyfin / Emby

```
Movies/The Dark Knight (2008)/The Dark Knight (2008).mkv
TV Shows/Breaking Bad (2008)/Season 01/Breaking Bad (2008) - S01E01.mkv
```

### Plex

```
Movies/The Dark Knight (2008)/The Dark Knight (2008).mkv
TV Shows/Breaking Bad/Season 01/S01E01.mkv
```

### Kodi

```
Movies/The Dark Knight (2008)/The Dark Knight (2008).mkv
TV Shows/Breaking Bad/Season01/Breaking Bad S01E01.mkv
```

`PathBuilder` is fully unit tested with expected input/output cases for all three media servers, for both movies and TV episodes.

---

## Worker Lifecycle

The encode worker is a launchd agent managed entirely through the `frostscribe worker` subcommand.

### Plist location
`~/Library/LaunchAgents/com.frostscribe.worker.plist`

### Commands

| Command | Action |
|---|---|
| `frostscribe worker start` | Writes the plist, calls `launchctl load`, worker starts immediately and on every login |
| `frostscribe worker stop` | Calls `launchctl unload`, removes the plist, worker stops and will not restart |
| `frostscribe worker restart` | Calls `launchctl unload` then `launchctl load` |
| `frostscribe worker status` | Shows whether the agent is loaded, the worker PID if running, and the current encode job |

### Generated plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.frostscribe.worker</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/frostscribe-worker</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>~/Library/Logs/Frostscribe/worker.log</string>
  <key>StandardErrorPath</key>
  <string>~/Library/Logs/Frostscribe/worker-error.log</string>
</dict>
</plist>
```

### Resource usage

The worker process is essentially zero overhead when idle — it sleeps for 5 seconds between queue polls. CPU only spikes when HandBrakeCLI is actively encoding, which is expected and intentional.

### Leak protection

Because the worker is a launchd agent, even if the process leaks or hangs, `frostscribe worker stop` calls `launchctl unload` which sends `SIGTERM` to the entire process group — the worker and any HandBrakeCLI child processes it spawned. Nothing is left orphaned.

---

## Vigil Mode

Vigil Mode is an opt-in autonomous ripping mode. It is **disabled by default**. Users must explicitly enable it in config or via `frostscribe init`.

Named after the monastic practice of keeping vigil — the monk who watches through the night and acts when needed, without being summoned.

### How it works

When Vigil Mode is enabled, the menu bar app uses the **DiskArbitration** framework to listen for optical disc insertion events. When a disc is detected:

1. Frostscribe scans the disc via `makemkvcon -r info disc:0`
2. TMDB lookup runs automatically using the disc name
3. The top TMDB result is selected automatically
4. The largest title on the disc is selected automatically
5. Ripping begins immediately
6. A native macOS notification is sent: "Ripping started — The Dark Knight (2008)"

The user receives a notification when ripping completes and the job is added to the encode queue. No interaction required.

### Safety

- Vigil Mode only activates when the menu bar app is running
- A notification is always sent when a rip starts, so you are never surprised
- TMDB lookup always runs in Vigil Mode — the top result is used automatically. Frostscribe will never rip a disc it cannot identify via TMDB
- If TMDB returns no results, Vigil Mode falls back to interactive mode for that disc and sends a notification: "Unknown disc — manual entry required"
- `frostscribe rip` always runs in interactive mode regardless of Vigil Mode setting

### Config

```json
{
  "vigil_mode": false
}
```

Enabled via `frostscribe init` or by editing config directly. Can also be toggled from the Settings view in the menu bar app.

---

## TMDB Integration

Frostscribe uses the TMDB API v3 to automatically identify discs and fill in title, year, and media type.

**Endpoint used:** `GET /search/multi` — searches both movies and TV shows in a single request, auto-detecting which type the result is.

**For TV shows:** `GET /tv/{id}/season/{n}` — fetches episode count for the selected season, pre-filling the episode list.

**Behavior without a key:** TMDB lookup is skipped entirely. The user is prompted to enter title, year, and media type manually. The tool is fully functional without TMDB.

**Behavior with a key:** Disc name is cleaned (underscores removed, year extracted) and sent to TMDB. Results are presented as a numbered list. User picks one or enters `0` to go manual. Empty input re-prompts.

---

## CLI Command Reference

```
frostscribe rip                  Start an interactive disc rip session
frostscribe status               Show current rip and encode status
frostscribe queue                Show the encode queue with progress
frostscribe worker start         Install and start the encode worker launchd agent
frostscribe worker stop          Stop and uninstall the encode worker
frostscribe worker restart       Restart the encode worker
frostscribe worker status        Show worker agent status and current job
frostscribe init                 Run the first-time setup wizard
frostscribe version              Print version information
```

---

## Dependencies

### Swift Packages

| Package | Purpose |
|---|---|
| `swift-argument-parser` | CLI subcommand parsing (Apple's official package) |
| No others for core | Foundation, FileManager, Process, URLSession are all built into Swift/macOS |

Frostscribe intentionally minimizes third-party dependencies. Everything needed — JSON encoding, file I/O, process spawning, HTTP requests, notifications — is available in Apple's frameworks.

### External Tools (user must install)

| Tool | Required | Install |
|---|---|---|
| MakeMKV | Yes | [makemkv.com](https://www.makemkv.com) |
| HandBrakeCLI | Yes | `brew install handbrake` |

---

## Build & Distribution

### Development build
```bash
swift build
```

### Release build
```bash
swift build -c release
```

### Binaries produced
- `.build/release/frostscribe` — the CLI tool
- `.build/release/frostscribe-worker` — the worker daemon
- The SwiftUI menu bar app is built via Xcode

### Homebrew distribution

A personal Homebrew tap at `github.com/trevholliday/homebrew-frostscribe` will host the formula. Users install with:

```bash
brew tap trevholliday/frostscribe
brew install frostscribe
```

The formula points at a GitHub release asset containing a pre-built universal binary (arm64 + x86_64).

The worker binary is installed alongside the CLI. `frostscribe worker start` installs the launchd plist pointing at the installed binary path automatically.

---

## Versioning Strategy

Frostscribe follows semantic versioning (`MAJOR.MINOR.PATCH`).

- `PATCH` — bug fixes, no new features
- `MINOR` — new features, backwards compatible config
- `MAJOR` — breaking config changes or major architectural shifts

v1.0.0 ships when: rip, encode, worker, and menu bar app are all functional on macOS with Jellyfin, Plex, and Kodi output support.

---

## Updates

| Date | Description |
|---|---|
| 2026-03-21 | MakeMKV error handling — `MSG:` lines with error codes (4xxx range) are now tracked during ripping. If any critical errors are detected, the rip is marked as failed and the job is not added to the encode queue. Prevents corrupt or incomplete rips from silently entering the encode pipeline. |
| 2026-03-21 | TMDB search cleanup — disc-specific terms such as `bluray`, `blu-ray`, `dvd`, `disc`, `disk`, `remux`, `uhd`, `hdr`, `4k` are stripped from the disc name before sending it to the TMDB search endpoint. Improves match accuracy for discs whose raw MakeMKV names include media format labels. |

---

## Out of Scope for v1

The following are explicitly not being built in v1. This list exists so we do not accidentally scope-creep while building.

- **Linux support** — no udev, no cross-platform PTY, no systemd
- **Windows support**
- **Multiple simultaneous encode workers**
- **Automatic disc detection** — no udev equivalent, insert disc and run `frostscribe rip`
- **Multiple optical drives** — single drive only, though queue design does not prevent adding this later
- **Web UI** — the menu bar app replaces this need
- **AMD GPU hardware encoding** — HandBrakeCLI does not support VAAPI; software x265 fallback only for non-Apple hardware
- **Audio ripping (CDs)** — video discs only
- **ISO backup mode** — MKV output only
- **Subtitle track selection** — subtitles are excluded in v1 (can be added via HandBrake preset later)
- **Homebrew tap** — manual install only until v1.0.0 is stable
