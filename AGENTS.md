# AGENTS.md

Notes for future Codex/agent work in this repo.

## Repo Setup

- Primary fork remote: `origin` -> `https://github.com/muddxyii/Kenshi-Online.git`.
- Upstream remote: `upstream` -> `https://github.com/The404Studios/Kenshi-Online.git`.
- Main working branch is `main`.
- Keep generated files out of Git. `build/`, `packages/`, compiled binaries, logs, saves, and local config are intentionally ignored.

## Build

- Preferred build command:

```bat
build.bat
```

- `build.bat` auto-detects common Steam install folders and also accepts a Kenshi install path:

```bat
build.bat "D:\SteamLibrary\steamapps\common\Kenshi"
```

- It also honors `KENSHI_DIR`:

```bat
set KENSHI_DIR=D:\SteamLibrary\steamapps\common\Kenshi
build.bat
```

- The build produces Release binaries in `build\bin\Release\`.
- The build also auto-deploys `KenshiMP.Core.dll`, `KenshiMP.Server.exe`, and layout files to the configured Kenshi directory when `KENSHI_DIR` is valid.

## Release Packaging

- After a successful Release build, create redistributable zips with:

```bat
package-release.bat
```

- Output folder:

```text
packages\
```

- Expected zips:
  - `KenshiMP-Player.zip`: player/joiner install; includes plugin DLL, injector, layouts, mod, installer/uninstaller.
  - `KenshiMP-Server.zip`: dedicated server only; includes `KenshiMP.Server.exe` and `server.json`.
  - `KenshiMP-Host.zip`: player package plus `KenshiMP.Server.exe` and `server.json`, so in-game `HOST GAME` can start a local server.

- Do not commit generated packages or build outputs.

## UPnP Context

- Commit `e95c536` replaced the broken Windows NAT/UPnP COM path with a direct UPnP/IGD implementation.
- The server now discovers the router via SSDP, parses the gateway description, sends SOAP `AddPortMapping`, retrieves external IP, and removes the mapping on shutdown.
- This was needed because the old Windows COM route stalled on the user's machine before the server finished starting.

## Hosting / Joining

- Default game port is UDP `27800`.
- Direct UPnP hosting gives friends the external IP plus `:27800`.
- playit.gg can be used instead; the local server still listens on `127.0.0.1:27800`, while friends use the playit assigned hostname/port.
- Master server disconnect warnings only affect server-browser registration, not direct joins.
- Setting `"masterServer": ""` in `server.json` disables master-server registration.

## Git Hygiene

- Do not re-track `build/`, `packages/`, generated binaries, logs, saves, `settings.cfg`, `.claude/settings.local.json`, or scratch files.
- `dist/` keeps source-like package assets and docs, but generated `dist/*.exe` and `dist/*.dll` should stay ignored.
- If a build dirties the tree, inspect carefully before staging; most generated dirt should be ignored or removed, not committed.
- Use `git clean -fdX -n` before disk cleanup, then only run the real clean when the dry run matches disposable generated files.

## Useful Commands

```bat
git status --short --branch
build.bat
package-release.bat
git clean -fdX -n
```
