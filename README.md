<p align="center">
  <img src="icon.jpg" width="160" alt="Frostscribe" />
</p>

<p align="center">
<pre>
███████╗██████╗  ██████╗ ███████╗████████╗███████╗ ██████╗██████╗ ██╗██████╗ ███████╗
██╔════╝██╔══██╗██╔═══██╗██╔════╝╚══██╔══╝██╔════╝██╔════╝██╔══██╗██║██╔══██╗██╔════╝
█████╗  ██████╔╝██║   ██║███████╗   ██║   ███████╗██║     ██████╔╝██║██████╔╝█████╗
██╔══╝  ██╔══██╗██║   ██║╚════██║   ██║   ╚════██║██║     ██╔══██╗██║██╔══██╗██╔══╝
██║     ██║  ██║╚██████╔╝███████║   ██║   ███████║╚██████╗██║  ██║██║██████╔╝███████╗
╚═╝     ╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝╚═════╝ ╚══════╝
                        ❄  disc to library · natively  ❄
</pre>
</p>

> **Work in progress.** Frostscribe is under active development and may be unstable until v1.0.0 is released. Expect rough edges.

# Frostscribe

A native macOS tool for ripping and preserving physical disc media to a local [Jellyfin](https://jellyfin.org), [Plex](https://plex.tv), or [Kodi](https://kodi.tv) library.

Frostscribe wraps `makemkvcon` and `HandBrakeCLI` into a polished interactive CLI. Insert a disc, run `frostscribe rip`, confirm the title, and walk away. The encode worker handles the rest in the background.

---

## Requirements

- macOS 14 or later
- [MakeMKV](https://makemkv.com) — download and install from makemkv.com
- [HandBrake](https://handbrake.fr) — `HandBrakeCLI` must be in your `$PATH` or configured via `frostscribe init`

```bash
brew install handbrake
```

---

## Installation

**Homebrew (recommended):**

```bash
brew tap trevholliday/frostscribe
brew install frostscribe
```

**Build from source:**

```bash
git clone https://github.com/trevholliday/frostscribe
cd frostscribe
swift build -c release
cp .build/release/frostscribe /usr/local/bin/
cp .build/release/frostscribe-worker /usr/local/bin/
```

---

## Setup

Run the setup wizard on first use:

```bash
frostscribe init
```

This creates `~/Library/Application Support/Frostscribe/config.json` with your output directories, media server selection, and optional API keys.

Install and start the background encode worker:

```bash
cp /usr/local/bin/frostscribe-worker /usr/local/bin/frostscribe-worker
launchctl load ~/Library/LaunchAgents/com.frostscribe.worker.plist
```

**Why the worker runs as a launchd agent**

Encoding is slow — a Blu-ray can take 30–90 minutes. The worker runs as a persistent background service managed by launchd so it survives terminal sessions, restarts after crashes, and starts automatically on login. It polls the encode queue every 10 seconds and processes jobs one at a time using VideoToolbox hardware encoding.

The worker plist lives at `~/Library/LaunchAgents/com.frostscribe.worker.plist` and logs to `~/Library/Logs/Frostscribe/worker.log`.

To stop the worker:

```bash
launchctl unload ~/Library/LaunchAgents/com.frostscribe.worker.plist
```

To restart it (e.g. after updating the binary):

```bash
launchctl kickstart -k gui/$(id -u)/com.frostscribe.worker
```

---

## Usage

### Rip a disc

Insert a disc, then:

```bash
frostscribe rip
```

Frostscribe will:
1. Scan the disc and display all titles with duration, chapters, size, and audio tracks
2. Look up the title on TMDB (if a key is configured)
3. Prompt you to confirm the output path
4. Rip the selected title to your temp directory
5. Add an encode job to the queue
6. Eject the disc

The background worker picks up the job and encodes it to your media library using VideoToolbox hardware encoding (H.265).

### Menu bar app

The **FrostscribeUI** menu bar app lives in your menu bar permanently. It shows rip and encode status at a glance, lets you open a full GUI rip flow window ("Rip Disc"), and manage settings.

**Vigil Mode** (default: on) means you are present — ripping is guided and interactive. Disabling Vigil Mode activates **AutoScribe**, which automatically rips any inserted disc without prompting. AutoScribe requires confirmation to enable in Settings.

### Check status

```bash
frostscribe status       # Current rip and encode status
frostscribe queue        # Encode queue with per-job progress
```

### Manage the worker

```bash
launchctl load ~/Library/LaunchAgents/com.frostscribe.worker.plist    # Start
launchctl unload ~/Library/LaunchAgents/com.frostscribe.worker.plist  # Stop
launchctl kickstart -k gui/$(id -u)/com.frostscribe.worker            # Restart
tail -f ~/Library/Logs/Frostscribe/worker.log                         # Follow logs
```

---

## Output formats

Output paths are automatically formatted for your configured media server.

**Jellyfin / Emby**
```
Movies/The Dark Knight (2008)/The Dark Knight (2008).mkv
TV Shows/Breaking Bad (2008)/Season 01/Breaking Bad (2008) - S01E01.mkv
```

**Plex**
```
Movies/The Dark Knight (2008)/The Dark Knight (2008).mkv
TV Shows/Breaking Bad/Season 01/S01E01.mkv
```

**Kodi**
```
Movies/The Dark Knight (2008)/The Dark Knight (2008).mkv
TV Shows/Breaking Bad/Season01/Breaking Bad S01E01.mkv
```

---

## Configuration

`~/Library/Application Support/Frostscribe/config.json`

| Field | Required | Description |
|---|---|---|
| `media_server` | Yes | `jellyfin`, `plex`, or `kodi` |
| `movies_dir` | Yes | Root directory for movie output |
| `tv_dir` | Yes | Root directory for TV show output |
| `temp_dir` | Yes | Staging area for raw ripped MKV files |
| `tmdb_api_key` | No | TMDB API v3 key for automatic title lookup |
| `makemkv_key` | No | MakeMKV registration key (trial mode without it) |
| `makemkv_bin` | No | Full path to `makemkvcon` (searched in `$PATH` if empty) |
| `handbrake_bin` | No | Full path to `HandBrakeCLI` (searched in `$PATH` if empty) |
| `event_hook` | No | Shell command executed on lifecycle events. Receives `FROSTSCRIBE_EVENT` (`rip_complete`, `encode_complete`, `encode_failed`), `FROSTSCRIBE_TITLE`, and `FROSTSCRIBE_BODY` as environment variables. Use this to send notifications via Home Assistant, Slack, Pushover, etc. |
| `vigil_mode` | No | `true` = Vigil Mode (interactive, user-guided — default). `false` = AutoScribe (auto-rips inserted discs without prompting) |
| `select_audio_tracks` | No | Prompt to choose which audio tracks to include before ripping (default: `false`) |

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full breakdown of the package structure, data flow, and design decisions.

---

## License

[MIT](LICENSE) © 2026 trevholliday
