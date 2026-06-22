# dj-factory

dj-factory is a Linux-first audio processing pipeline for DJ prep.

It combines tools for:
- Tidal downloading
- automatic tagging with OneTagger
- loudness normalization and AIFF conversion
- stem generation
- detune detection and tagging

## Runtime model

dj-factory supports **immutable Linux hosts**.

It is designed to run through **Distrobox** by default, which makes it a good fit for systems like Aurora, Silverblue, Kinoite, and similar read-only/atomic desktops.

- **Distrobox is the intended runtime**
- the app enters or creates its container automatically
- host package installation is not the primary path

## Repo-local artifacts

Build and runtime artifacts stay inside the repo where possible, but they are intentionally not committed.

Ignored local-only paths include:
- `stemgen-venv/`
- `tidal-venv/`
- `bin/`
- `logs/`
- `tmp/`
- `.cache/`
- `.state/`
- `scripts/tidal_playlist.txt`

`tidal-dl-ng` is installed by the bootstrap step from the source configured in `lib/bootstrap.sh` (`TIDAL_PIP_SPEC` can override it). Do not commit the `tidal-venv/` directory: it is large and may contain machine-specific or login-related data.

## Launch

From the repo root:

```bash
chmod +x main.sh
./main.sh
```

By default this will use the configured Distrobox container.
