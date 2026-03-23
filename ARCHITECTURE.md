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
13. [CLI Command Reference](#cli-command-reference)
14. [Dependencies](#dependencies)
15. [Build & Distribution](#build--distribution)
16. [Versioning Strategy](#versioning-strategy)
17. [Out of Scope for v1](#out-of-scope-for-v1)

---

## Vision

Frostscribe is a native macOS application that acts as a digital librarian — taking physical disc media (Blu-ray, DVD) and permanently preserving it in a local media library. Like the monks of a scriptorium transcribing manuscripts from one medium to another, Frostscribe carefully identifies, rips, encodes, and catalogs each disc into a format that Jellyfin, Plex, or Kodi can immediately recognize and serve.

The name is built from two ideas:
- **Frost** — cold, permanent, preserved storage
- **Scribe** — the act of transcribing from one medium to another

By default, Frostscribe is an interactive tool designed for a person who is sitting at their homelab, swapping discs, and building their library intentionally. For users who want fully automatic ripping, **Vigil Mode** can be enabled — see the Vigil Mode section.

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
│   (interactive)     (monitor/rip)  (launchd agent)           │
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

Frostscribe is organized as a Swift Package with multiple targets sharing a single core library. The SwiftUI menu bar app lives in a separate Xcode project at the repo root that references the package as a local SPM dependency.

```
Frostscribe/
├── Package.swift
├── ARCHITECTURE.md
├── README.md
│
├── Sources/
│   ├── FrostscribeCore/         ← shared business logic (no UI, no CLI)
│   │   ├── Config/
│   │   │   ├── Config.swift
│   │   │   └── MediaServer.swift
│   │   ├── Models/
│   │   │   ├── RipJob.swift
│   │   │   ├── EncodeJob.swift
│   │   │   ├── DiscTitle.swift
│   │   │   ├── DiscScanResult.swift
│   │   │   ├── AudioTrack.swift
│   │   │   ├── DiscType.swift
│   │   │   └── RipRecord.swift
│   │   ├── Protocols/
│   │   │   ├── QueueManaging.swift
│   │   │   ├── StatusManaging.swift
│   │   │   ├── NotificationServing.swift
│   │   │   ├── MakeMKVRunning.swift
│   │   │   ├── HandBrakeRunning.swift
│   │   │   └── DiscEjecting.swift
│   │   ├── UseCases/
│   │   │   └── RipUseCase.swift
│   │   ├── Services/
│   │   │   ├── StatusManager.swift
│   │   │   ├── QueueManager.swift
│   │   │   ├── NotificationService.swift
│   │   │   ├── TMDBClient.swift
│   │   │   ├── RipHistoryStore.swift
│   │   │   └── RipEstimator.swift
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
│   ├── FrostscribeCLI/          ← interactive command line tool
│   │   ├── main.swift
│   │   ├── Commands/
│   │   │   ├── InitCommand.swift
│   │   │   ├── RipCommand.swift
│   │   │   ├── StatusCommand.swift
│   │   │   ├── QueueCommand.swift
│   │   │   └── WorkerCommand.swift
│   │   └── Display/
│   │       ├── Colors.swift
│   │       ├── ProgressBar.swift
│   │       └── Prompt.swift
│   │
│   └── FrostscribeWorker/       ← launchd encode worker daemon
│       └── main.swift
│
├── Tests/
│   └── FrostscribeCoreTests/
│       ├── MakeMKVParserTests.swift
│       ├── PathBuilderTests.swift
│       ├── QueueManagerTests.swift
│       ├── RipUseCaseTests.swift
│       └── EncoderPresetTests.swift
│
└── FrostscribeUI/               ← Xcode project (separate from SPM package)
    └── FrostscribeUI/
        ├── FrostscribeApp.swift
        ├── Info.plist
        ├── FrostscribeUI.entitlements
        ├── Design/
        │   └── FrostTheme.swift
        ├── MenuBar/
        │   ├── MenuBarView.swift
        │   └── MenuBarIcon.swift
        ├── ViewModels/
        │   ├── StatusViewModel.swift
        │   ├── QueueViewModel.swift
        │   └── RipFlowViewModel.swift
        ├── Views/
        │   ├── StatusSectionView.swift
        │   ├── QueueSectionView.swift
        │   ├── QueueRowView.swift
        │   ├── SettingsView.swift
        │   └── Rip/
        │       ├── RipFlowView.swift
        │       ├── RipIdleView.swift
        │       ├── RipScanningView.swift
        │       ├── TitleSelectionView.swift
        │       ├── MediaTypeView.swift
        │       ├── TMDBSearchView.swift
        │       ├── TVEpisodeView.swift
        │       ├── AudioTrackSelectionView.swift
        │       ├── ConfirmationView.swift
        │       ├── RippingProgressView.swift
        │       └── RipCompleteView.swift
        └── Vigil/
            ├── VigilWatcher.swift
            └── VigilViewModel.swift
```

---

## Component Breakdown

### FrostscribeCore

The heart of the application. Contains all business logic with zero UI dependencies. The CLI, the menu bar app, and the worker all import this package.

**Config/**
- `Config.swift` — the main configuration struct. Loaded from and saved to `~/Library/Application Support/Frostscribe/config.json`. Provides sensible defaults so the tool works out of the box after setting required fields.
- `MediaServer.swift` — enum defining supported media servers (`jellyfin`, `plex`, `kodi`) and their output path formatting rules.

**Models/**
- `RipJob.swift` — represents an active or completed rip operation. Written to `status.json` during ripping.
- `EncodeJob.swift` — represents a single entry in the encode queue (`queue.json`). Has states: `pending`, `encoding`, `done`, `error`.
- `DiscTitle.swift` — represents a single title found on a disc during the MakeMKV scan phase. Contains title number, duration, chapter count, file size, filename, video resolution, subtitle count, order weight, and a list of `AudioTrack` values.
- `DiscScanResult.swift` — top-level value type returned by a disc scan: title list, disc name, disc type.
- `AudioTrack.swift` — represents a single audio track on a title. Contains language, codec, channel layout, and an `isLossless` flag derived from codec name (DTS-HD MA, TrueHD, FLAC, PCM, LPCM).
- `DiscType.swift` — enum (`dvd`, `bluray`, `uhd`, `unknown`) parsed from the raw MakeMKV `CINFO:1` string. Used for encoder preset selection and rip history estimation.
- `RipRecord.swift` — Codable struct persisted to `riphistory.db`. Captures disc type, title size in bytes, rip duration in seconds, job label, success flag, and timestamp. Powers the rip time estimator.

**Protocols/**

Protocol abstractions that decouple callers from concrete implementations. All services and runners conform to their respective protocol, enabling injection and stub-based testing without touching real discs, files, or processes.

- `QueueManaging.swift` — read, add, and update encode jobs in `queue.json`.
- `StatusManaging.swift` — read and write rip status to `status.json`.
- `NotificationServing.swift` — request notification authorization and send notifications.
- `MakeMKVRunning.swift` — async scan and rip operations. Default no-op `scan()` extension provided.
- `HandBrakeRunning.swift` — async encode operation.
- `DiscEjecting.swift` — eject the optical disc.

**UseCases/**
- `RipUseCase.swift` — orchestrates the core rip flow: writes `.ripping` status, calls the runner, finds the output MKV, ejects the disc, adds the encode job to the queue, and resets status to `.idle` via `defer`. Accepts all dependencies as protocol types so it can be tested with stubs. `RipCommand` is presentation-only; all rip business logic lives here.

**Services/**
- `StatusManager.swift` — atomic read/write of `status.json`. Maintains history of completed jobs (last 20). Written atomically using a temp file + rename to prevent corruption.
- `QueueManager.swift` — atomic read/write of `queue.json`. Provides methods to add jobs, update progress, mark complete, and read active jobs. Uses file locking to prevent the CLI and worker from writing simultaneously.
- `NotificationService.swift` — sends macOS native notifications (via `UserNotifications` framework) when a rip or encode completes. Requires no external service.
- `TMDBClient.swift` — HTTP client for TMDB API v3. Performs multi-search (auto-detects movie vs TV), fetches season episode counts. Gracefully no-ops if a key is not configured.
- `RipHistoryStore.swift` — SQLite-backed store (via GRDB) for `RipRecord` entries. Database lives at `riphistory.db` in app support. Runs schema migrations on first open. Provides insert and size-range query methods used by the estimator. Gracefully degrades to no-op if the database cannot be opened.
- `RipEstimator.swift` — estimates rip time for a given disc type and title size by averaging the MB/s rate from past records within ±25% of the target size. Falls back to empirical defaults (DVD ~9 MB/s, Blu-ray ~18 MB/s, UHD ~30 MB/s) when fewer than 2 matching records exist. Returns a `RipEstimate` with a `confidence` field (`.measured(sampleCount:)` or `.fallback`).

**Ripping/**
- `MakeMKVRunner.swift` — spawns `makemkvcon` as a child process, captures output via a pipe, and streams it line by line to the parser. Handles both the `info` (disc scan) and `mkv` (rip) modes. Conforms to `MakeMKVRunning`. Returns `DiscScanResult`.
- `MakeMKVParser.swift` — pure parsing logic with no I/O. Takes raw output lines from makemkvcon and produces structured data: `CINFO` → disc metadata, `TINFO` → title metadata, `MSG` → user-facing messages, `PRGV` → progress values. Fully unit tested.
  - **MSG error handling:** `MSG` codes in the 4xxx range are errors, but not all are fatal. Codes where the message text contains `"attempting to work around"` (e.g. MSG:4004 — corrupt sector recovered) are warnings that MakeMKV handled internally — the rip can continue and succeed. Only 4xxx messages that do **not** contain `"attempting to work around"` should be treated as fatal and abort the rip.
- `DiscEjector.swift` — wraps `drutil eject` with a retry loop (5 attempts, 2 second delay).

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
- `InitCommand.swift` — first-time setup wizard. Detects HandBrakeCLI and MakeMKV at startup and offers to install HandBrakeCLI via Homebrew (streaming live output). MakeMKV must be downloaded manually from makemkv.com. Prompts for all config fields including notifications and audio track selection.
- `RipCommand.swift` — the primary interactive rip flow. Scans the disc, presents titles, queries TMDB, prompts user for confirmation, rips the selected title, and adds it to the encode queue.
- `StatusCommand.swift` — reads `status.json` and `queue.json` and prints a formatted summary.
- `QueueCommand.swift` — displays the encode queue with progress bars.
- `WorkerCommand.swift` — manages the launchd encode worker agent. Subcommands: `start`, `stop`, `restart`, `status`.

**Display/**
- `Colors.swift` — ANSI escape codes for terminal coloring. Detects color support and falls back gracefully.
- `ProgressBar.swift` — renders an ASCII progress bar with spinner for rip and encode progress.
- `Prompt.swift` — ASCII art banners and interactive prompt helpers for the main screen and rip-again prompt.

---

### FrostscribeUI

A macOS SwiftUI menu bar application packaged as a proper `.app` bundle via an Xcode project at `FrostscribeUI/FrostscribeUI.xcodeproj`. The Xcode project references the repo root `Package.swift` as a local SPM dependency to import `FrostscribeCore`. Lives in the menu bar permanently, showing at a glance whether a rip or encode is in progress, and providing a full GUI rip flow for users who prefer not to use the CLI.

**FrostscribeApp.swift** — `@main` struct. Owns `StatusViewModel`, `QueueViewModel`, and `VigilViewModel` as `@State` properties and injects them via `.environment()`. Defines the `MenuBarExtra`, the `Window("Rip Disc")` scene, and the `Settings` scene.

**MenuBar/**
- `MenuBarIcon.swift` — dynamic SF Symbol in the menu bar that reacts to ripper status: snowflake (idle), optical disc pulsing (ripping), film stack pulsing (encoding), exclamation triangle (error). Shows an eye indicator when Vigil Mode is active.
- `MenuBarView.swift` — the popover that appears when the user clicks the icon. Shows rip status, encode queue, and a footer with "Rip Disc", Settings, and version string.

**ViewModels/**
- `StatusViewModel.swift` — `@MainActor @Observable` class that polls `status.json` every 3 seconds.
- `QueueViewModel.swift` — `@MainActor @Observable` class that polls `queue.json` every 3 seconds.
- `RipFlowViewModel.swift` — `@MainActor @Observable` state machine that drives the GUI rip flow. `phase` enum covers: `idle`, `scanning`, `titleSelection`, `mediaType`, `tmdbSearch`, `tvEpisode`, `audioTrackSelection`, `confirmation`, `ripping`, `done`, `error`. Owns all async Tasks; `reset()` cancels them. Computes `ripEstimate` (via `RipEstimator`) when entering the confirmation phase and exposes `estimatedSecondsRemaining` during ripping.
- `NavigationCoordinator.swift` — `@MainActor @Observable` class shared between the menu bar popover and the main window. Holds `selectedSection: AppSection?` which drives which panel is visible. `AppSection` covers `rip`, `ripJob`, `encodeQueue`, `history`, `logs`, `settings`.

**Views/**
- `StatusSectionView.swift` — displays current rip job with a live progress bar when ripping, otherwise shows "No disc active".
- `QueueSectionView.swift` — displays the encode queue list with an active count badge.
- `QueueRowView.swift` — single queue row: status icon, title, status pill, and an inline progress view for encoding jobs.
- `SettingsView.swift` — grouped `Form` for editing `config.json`. Fields for paths, media server, API keys, and option toggles (notifications, Vigil Mode, select audio tracks).

**Views/Rip/** — stateless step views driven by `RipFlowViewModel.phase`:
- `RipFlowView.swift` — coordinator. Switches on `vm.phase` and renders the correct step view. Toolbar Cancel button shown on all cancellable phases.
- `RipIdleView.swift` — snowflake icon and "Scan Disc" button.
- `RipScanningView.swift` — indeterminate spinner while `makemkvcon` runs.
- `TitleSelectionView.swift` — list of disc titles with duration, chapters, size, and audio summary. Lossless tracks highlighted.
- `MediaTypeView.swift` — two large tappable cards: Movie / TV Show.
- `TMDBSearchView.swift` — pre-filled search field, results list, "Enter manually" fallback. Handles no-key state gracefully.
- `TVEpisodeView.swift` — season and episode steppers.
- `AudioTrackSelectionView.swift` — per-track toggles with language, codec, and lossless badge. Only shown when `select_audio_tracks` is enabled and the title has more than one track.
- `ConfirmationView.swift` — read-only summary of title, output path, preset, and audio before committing.
- `RippingProgressView.swift` — determinate progress bar tinted frostCyan, pulsing optical disc icon.
- `RipCompleteView.swift` — done (teal checkmark, "Rip Another") or error (alert triangle, "Try Again").

**Vigil/**
- `VigilWatcher.swift` — wraps the DiskArbitration framework. Registers a `DADiskAppearedCallback` that detects optical disc insertion and posts a `Notification.Name.vigilDiscInserted` notification.
- `VigilViewModel.swift` — `@MainActor @Observable` class that observes disc insertion notifications, orchestrates the full auto-rip flow, and sends native notifications. TV discs send a notification and stop — episode selection requires running `frostscribe rip` interactively.

**Design/**
- `FrostTheme.swift` — SwiftUI color constants matching the CLI frost palette, plus shared spacing, corner radius, and popover width constants.

---

### FrostscribeWorker

A minimal executable that runs as a launchd agent. Imports `FrostscribeCore` for all encoding logic.

**main.swift** — starts the encode worker loop. Polls `queue.json` every 5 seconds for pending jobs. Encodes one job at a time using `HandBrakeRunner`. Updates progress in real time. Sends a native macOS notification on completion. Handles `SIGTERM` gracefully — waits for the current encode to finish before exiting.

The worker is installed to `~/Library/LaunchAgents/com.frostscribe.worker.plist` by `frostscribe worker start` and loaded immediately via `launchctl load`. It starts automatically on login thereafter.

---

## Configuration

**Location:** `~/Library/Application Support/Frostscribe/config.json`

**Created:** automatically on first run of `frostscribe init`.

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
  "notifications_enabled": true,
  "vigil_mode": false,
  "select_audio_tracks": false
}
```

**Fields:**

| Field | Required | Description |
|---|---|---|
| `media_server` | Yes | `jellyfin`, `plex`, or `kodi` |
| `movies_dir` | Yes | Root directory for movie output |
| `tv_dir` | Yes | Root directory for TV show output |
| `temp_dir` | Yes | Staging area for raw ripped MKV files before encoding |
| `tmdb_api_key` | No | TMDB API v3 key. Tool works without it but requires manual title entry |
| `makemkv_key` | No | MakeMKV registration key. Without it MakeMKV runs in trial mode (30 day limit) |
| `makemkv_bin` | No | Full path to `makemkvcon`. If empty, searches known paths then `$PATH` |
| `handbrake_bin` | No | Full path to `HandBrakeCLI`. If empty, searches `$PATH` |
| `notifications_enabled` | No | Send native macOS notifications on job completion. Defaults to `true` |
| `vigil_mode` | No | `true` = Vigil Mode (interactive, default). `false` = AutoScribe (auto-rips inserted discs without prompting) |
| `select_audio_tracks` | No | Prompt the user to choose which audio tracks to include before ripping. Defaults to `false` |

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

All state files live at `~/Library/Application Support/Frostscribe/`.

### status.json

Written by the rip flow. Read by the CLI status command and the menu bar app.

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

The JSON files are written atomically: data is written to a `.tmp` file first, then renamed to the final path. `rename()` is atomic on the same filesystem volume, preventing corrupt reads if the process is killed mid-write.

### riphistory.db

SQLite database written by `RipHistoryStore` via GRDB. Created automatically on first rip. Schema is managed by GRDB's `DatabaseMigrator` — migrations run on app launch and are idempotent.

**Table: `rip_records`**

| Column | Type | Description |
|---|---|---|
| `id` | TEXT (UUID) | Primary key |
| `timestamp` | DATETIME | When the rip completed |
| `disc_type` | TEXT | `dvd`, `bluray`, `uhd`, or `unknown` |
| `title_size_bytes` | INTEGER | Raw MKV size of the ripped title |
| `rip_duration_seconds` | REAL | Wall-clock time from rip start to MKV found |
| `job_label` | TEXT | Human-readable title (e.g. "The Dark Knight (2008)") |
| `success` | BOOLEAN | 1 if rip completed successfully |

Indexed on `(disc_type, title_size_bytes)` for fast estimator queries.

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

**Vigil Mode** is the default interactive mode — the user is present, guiding each rip. Disabling Vigil Mode activates **AutoScribe**, the autonomous ripping mode. AutoScribe requires explicit confirmation to enable (destructive action prompt in Settings).

Named after the monastic practice of keeping vigil — the monk who watches through the night and acts when needed, without being summoned.

### How it works

When AutoScribe is active (Vigil Mode off), the menu bar app uses the **DiskArbitration** framework to listen for optical disc insertion events. When a disc is detected:

1. Frostscribe scans the disc via `makemkvcon -r info disc:0`
2. TMDB lookup runs automatically using the disc name
3. The top TMDB result is selected automatically
4. The largest title on the disc is selected automatically
5. **Movies:** ripping begins immediately. A native notification is sent when ripping starts and again when the encode job is added to the queue.
6. **TV shows:** ripping does not start automatically. A notification is sent: "TV Disc Identified — run `frostscribe rip` to select the episode."

### Safety

- AutoScribe only activates when the menu bar app is running
- A notification is always sent when a rip starts, so you are never surprised
- TMDB lookup always runs — the top result is used automatically. Frostscribe will never rip a disc it cannot identify via TMDB
- If TMDB returns no results, Vigil Mode stops and sends a notification: "Unknown disc — manual entry required"
- `frostscribe rip` always runs in interactive mode regardless of Vigil Mode setting

### Config

```json
{
  "vigil_mode": true
}
```

`true` = Vigil Mode (default) — user is present, ripping is interactive.
`false` = AutoScribe — discs are ripped automatically without prompting.

Toggled from the Settings view in the menu bar app. Disabling Vigil Mode (enabling AutoScribe) requires a confirmation dialog.

---

## TMDB Integration

Frostscribe uses the TMDB API v3 to automatically identify discs and fill in title, year, and media type.

**Endpoint used:** `GET /search/multi` — searches both movies and TV shows in a single request, auto-detecting which type the result is.

**For TV shows:** `GET /tv/{id}/season/{n}` — fetches episode count for the selected season, pre-filling the episode list.

**Behavior without a key:** TMDB lookup is skipped entirely. The user is prompted to enter title, year, and media type manually. The tool is fully functional without TMDB.

**Behavior with a key:** Disc name is cleaned (underscores removed, format labels stripped, year extracted) and sent to TMDB. Results are presented as a numbered list. User picks one or enters `0` to go manual.

---

## CLI Command Reference

```
frostscribe init                 Run the first-time setup wizard
frostscribe rip                  Start an interactive disc rip session
frostscribe status               Show current rip and encode status
frostscribe queue                Show the encode queue with progress
frostscribe worker start         Install and start the encode worker launchd agent
frostscribe worker stop          Stop and uninstall the encode worker
frostscribe worker restart       Restart the encode worker
frostscribe worker status        Show worker agent status and current job
frostscribe version              Print version information
```

---

## Dependencies

### Swift Packages

| Package | Purpose |
|---|---|
| `swift-argument-parser` | CLI subcommand parsing (Apple's official package) |
| `GRDB.swift` | SQLite wrapper for `RipHistoryStore` — type-safe queries, migrations, `Sendable` `DatabaseQueue` |

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

A personal Homebrew tap at `github.com/trevholliday/homebrew-frostscribe` hosts the formula. Users install with:

```bash
brew tap trevholliday/frostscribe
brew install frostscribe
```

Releases are cut with `make release VERSION=x.y.z`. GitHub Actions builds arm64 and x86_64 binaries, creates a GitHub Release, and updates the tap formula automatically.

---

## Versioning Strategy

Frostscribe follows semantic versioning (`MAJOR.MINOR.PATCH`).

- `PATCH` — bug fixes, no new features
- `MINOR` — new features, backwards compatible config
- `MAJOR` — breaking config changes or major architectural shifts

---

## Out of Scope for v1

The following are explicitly not being built in v1.

- **Linux support** — no udev, no cross-platform PTY, no systemd
- **Windows support**
- **Multiple simultaneous encode workers**
- **Multiple optical drives** — single drive only, though queue design does not prevent adding this later
- **Web UI** — the menu bar app replaces this need
- **AMD GPU hardware encoding** — HandBrakeCLI does not support VAAPI; software x265 fallback only for non-Apple hardware
- **Audio ripping (CDs)** — video discs only
- **ISO backup mode** — MKV output only
- **Subtitle track selection** — subtitles are excluded in v1 (can be added via HandBrake preset later)
