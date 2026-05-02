# Kenshi-Online

**Co-op multiplayer for Kenshi, with a native in-game multiplayer menu and dedicated server support.**

Kenshi-Online adds multiplayer through an Ogre plugin loaded by Kenshi, ENet networking, and native MyGUI layouts. Players can join a host, chat, see other players, and sync world state without building the project from source.

## Packages

If you are playing, use one of the prebuilt zips from a release or from whoever built the mod. You do not need the source tree.

Use the zip that matches what you want to do:

| Package | Use this if you want to... | Includes |
|---------|-----------------------------|----------|
| `KenshiMP-Player.zip` | Join someone else's game | Client plugin, installer, multiplayer button/layouts, mod files |
| `KenshiMP-Host.zip` | Play and host from the same PC | Player package plus `KenshiMP.Server.exe` and `server.json` |
| `KenshiMP-Server.zip` | Run a standalone dedicated server | Server executable and config only |

Developers can create these zips locally with `package-release.bat`; they are written to:

```text
packages\
```

## Install For Players

1. Extract `KenshiMP-Player.zip`.
2. Run `install.bat`.
3. If the installer cannot find Kenshi, point it at the folder containing `kenshi_x64.exe`.
4. Launch Kenshi normally.
5. Click `MULTIPLAYER`, then `JOIN GAME`.
6. Enter the host address and port.

The default game port is UDP `27800`.

## Hosting

### Host From Your PC

1. Extract `KenshiMP-Host.zip`.
2. Run `install.bat`.
3. Launch Kenshi normally.
4. Click `MULTIPLAYER`, then `HOST GAME`.
5. Share your address with friends.

The server tries UPnP automatically. If UPnP works, the server log prints the external address friends can use. If UPnP does not work, forward UDP `27800` to your PC or use a tunnel such as playit.gg.

### Dedicated Server

1. Extract `KenshiMP-Server.zip`.
2. Edit `server.json` if needed.
3. Run `KenshiMP.Server.exe`.

Example config:

```json
{
  "serverName": "My Kenshi Server",
  "port": 27800,
  "maxPlayers": 16,
  "pvpEnabled": true,
  "gameSpeed": 1.0
}
```

### Server Commands

```text
status      Show server info
players     List connected players
kick <id>   Kick a player
say <msg>   Broadcast a system message
save        Save world state
stop        Shut down the server
```

### Master Server

The server can register with a master server for browser discovery. Direct joins still work even if master-server registration fails.

To disable registration, set this in `server.json`:

```json
"masterServer": ""
```

## Controls

| Key | Action |
|-----|--------|
| `F1` | Open or close the multiplayer menu |
| `Enter` | Open or close chat |
| `Tab` | Toggle player list |
| `Insert` | Toggle debug/loading log |
| `` ` `` | Toggle debug info |
| `Escape` | Close multiplayer panels |

## Features

- Up to 16 players on one server.
- Dedicated server with persistence and console commands.
- Native Kenshi/MyGUI multiplayer menu, HUD, chat, and player list.
- ENet UDP networking on port `27800`.
- Server-authoritative combat and world state.
- Zone-based synchronization for nearby entities.
- Optional master-server browser registration.

## Building From Source

### Requirements

- Visual Studio 2022, or Visual Studio 2019, with the **Desktop development with C++** workload.
- CMake 3.20+.
- Git.

No vcpkg is required. Third-party dependencies are vendored directly in `lib/`, so a normal clone has everything required to build.

### One-Click Build

```bat
git clone https://github.com/muddxyii/Kenshi-Online.git
cd Kenshi-Online
build.bat
```

`build.bat` detects Visual Studio, finds common Steam Kenshi install folders, configures CMake, builds Release, and runs unit tests.

If Kenshi is installed somewhere custom, pass the folder containing `kenshi_x64.exe`:

```bat
build.bat "D:\SteamLibrary\steamapps\common\Kenshi"
```

Or set `KENSHI_DIR` for the current terminal:

```bat
set KENSHI_DIR=D:\SteamLibrary\steamapps\common\Kenshi
build.bat
```

### Manual Build

```bat
git clone https://github.com/muddxyii/Kenshi-Online.git
cd Kenshi-Online
cmake -B build -G "Visual Studio 17 2022" -A x64 -DKENSHI_DIR:PATH="D:\SteamLibrary\steamapps\common\Kenshi"
cmake --build build --config Release
build\bin\Release\KenshiMP.UnitTest.exe
```

### Build Output

```text
build\bin\Release\
    KenshiMP.Core.dll
    KenshiMP.Server.exe
    KenshiMP.Injector.exe
    KenshiMP.MasterServer.exe
    KenshiMP.TestClient.exe
    KenshiMP.IntegrationTest.exe
    KenshiMP.UnitTest.exe
```

### Create Release Packages

After a successful Release build:

```bat
package-release.bat
```

This creates:

```text
packages\
    KenshiMP-Player.zip
    KenshiMP-Host.zip
    KenshiMP-Server.zip
```

Do not commit `build\` or `packages\`; both are generated.

## Developer Notes

### Architecture

```text
KenshiMP.Injector.exe     Modifies Plugins_x64.cfg and launches Kenshi
KenshiMP.Core.dll         Ogre plugin loaded by Kenshi
KenshiMP.Server.exe       Dedicated server
KenshiMP.MasterServer.exe Optional server browser registry
KenshiMP.Common.lib       Shared protocol, config, serialization
KenshiMP.Scanner.lib      Pattern scanning and hook helpers
```

### Project Structure

```text
KenshiMP.Common\       Shared protocol/types/config
KenshiMP.Scanner\      Pattern scanning and MinHook wrapper
KenshiMP.Core\         Kenshi plugin, hooks, UI, networking, sync
KenshiMP.Server\       Dedicated server and UPnP
KenshiMP.MasterServer\ Server browser registry
KenshiMP.Injector\     Win32 launcher/installer
dist\                  Package assets, layouts, install scripts, docs
lib\                   Vendored third-party dependencies
```

### Networking

- Protocol: ENet over UDP.
- Default port: `27800`.
- Tick rate: 20 Hz.
- Max players: 16.
- Channels: reliable ordered, reliable unordered, unreliable sequenced.

### Synced State

- Player positions, rotations, animations, and names.
- NPC positions and zone-based AI state.
- Combat events, damage, deaths, and knockouts.
- Buildings, items, time, weather, game speed, and chat.

### Injection Method

Kenshi-Online uses Kenshi's Ogre3D plugin system. The installer adds `Plugin=KenshiMP.Core` to `Plugins_x64.cfg`, then Ogre loads `KenshiMP.Core.dll` during startup. No process injection is required.

### Dependencies

- [ENet](https://github.com/lsalzman/enet) - UDP networking.
- [MinHook](https://github.com/TsudaKageyu/minhook) - x64 API hooking.
- [nlohmann/json](https://github.com/nlohmann/json) - JSON for C++.
- [spdlog](https://github.com/gabime/spdlog) - logging.
- [Dear ImGui](https://github.com/ocornut/imgui) - debug tooling.

## Credits

Built on community reverse-engineering work:

- [RE_Kenshi](https://github.com/BFrizzleFoShizzle/RE_Kenshi) - Ogre plugin injection approach.
- [KenshiLib](https://github.com/KenshiReclaimer/KenshiLib) - game structure definitions.
- [Kenshi Online](https://github.com/The404Studios/Kenshi-Online) - original project and memory-address reference.
- [OpenConstructionSet](https://github.com/lmaydev/OpenConstructionSet) - game data SDK.

## License

MIT License
