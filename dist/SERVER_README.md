# KenshiMP Server Package

Use this package to run a dedicated server without installing the Kenshi client plugin.

## Run

1. Extract this zip anywhere on the server PC.
2. Edit `server.json` if you want to change the name, port, player count, or master server.
3. Run `KenshiMP.Server.exe`.

The default game port is UDP `27800`. The server tries UPnP automatically. If UPnP is unavailable, forward UDP `27800` to the server PC.

## Included

- `KenshiMP.Server.exe` - dedicated server.
- `server.json` - server configuration.

## Joining

Players need the player package installed in their Kenshi folder, then they connect to the host address and port.
