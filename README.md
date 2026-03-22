# Frostscribe

A native macOS tool for ripping and preserving physical disc media to a local [Jellyfin](https://jellyfin.org), [Plex](https://plex.tv), or [Kodi](https://kodi.tv) library.

Frostscribe wraps `makemkvcon` and `HandBrakeCLI` into a polished interactive CLI. Insert a disc, run `frostscribe rip`, confirm the title, and walk away. The encode worker handles the rest in the background.

---

## Requirements

- macOS 14 or later
- [MakeMKV](https://makemkv.com) — `makemkvcon` must be in your `$PATH` or configured via `frostscribe init`
- [HandBrake](https://handbrake.fr) — `HandBrakeCLI` must be in your `$PATH` or configured via `frostscribe init`

```
brew install handbrake
```

---

## Installation

Build from source:

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

Start the background encode worker:

```bash
frostscribe worker start
```

The worker installs as a launchd agent and starts automatically on login.

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

### Check status

```bash
frostscribe status       # Current rip and encode status
frostscribe queue        # Encode queue with per-job progress
```

### Manage the worker

```bash
frostscribe worker start     # Install and start
frostscribe worker stop      # Stop and uninstall
frostscribe worker restart   # Restart
frostscribe worker status    # Show worker status and current job
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
| `notifications_enabled` | No | Native macOS notifications on job completion (default: `true`) |

---

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full breakdown of the package structure, data flow, and design decisions.

---

## License

[MIT](LICENSE) © 2026 trevholliday
