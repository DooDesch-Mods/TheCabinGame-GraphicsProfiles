# CabinGraphicsProfiles

> 🛟 **Need help or found a bug?** Get support at [support.doodesch.de/graphicsprofiles](https://support.doodesch.de/graphicsprofiles).

Offers explicit Balanced and Performance profiles for GI, shadows, reflections and effects, plus Restore previous. Other graphics options stay unchanged.

Requires [UE4SS 3.0.1 or later](https://www.nexusmods.com/thecabingame/mods/4). Install UE4SS separately.

1. Close the game and install UE4SS in your game folder.
2. Copy `Mods/CabinGraphicsProfiles` into `the_cabin_game/Binaries/Win64/ue4ss/Mods`.
3. Copy the archive's `the_cabin_game/Content/Paks/~mods` files to the same path in your game folder. Keep the three container files together.

Use [Mod Settings](https://www.nexusmods.com/thecabingame/mods/6) to choose a profile or **Restore previous** from its menu. The ZIP also includes `README.profile_templates.json` for manual configuration. No profile is applied on startup.

Use **Restore previous** before removal to undo a profile. Then close the game and remove only `Mods/CabinGraphicsProfiles` and its three named container files. Keep a backup of `Scripts/settings.dat` and `Scripts/previous_graphics.dat` if you want to retain the stored preferences and previous values.

## Build and release

Tested baseline: Steam build `25553694`, Unreal 5.5 and UE4SS `v3.0.1-1164-g5e627997`.

Use Python 3.13. Run `python -m pip install -r requirements-dev.txt`, `python -m unittest discover -s tests -v`, `python tests/check_lua.py`, then `python tools/package.py`.

The builder writes a deterministic ZIP and checksum in `dist`. Overlay containers are committed build inputs; CI packages them and does not cook Unreal assets or download the game. Runtime Lua and containers are covered by the acceptance fingerprint. `python tools/package.py --release` rejects a missing or stale product acceptance. Multiplayer and a separate isolated gameplay session are explicitly not applicable to this local graphics provider.

CI checks Linux and Windows. See [publishing](docs/publishing.md) for the GitHub/Nexus flow and [Nexus description](docs/nexus.md) for the prepared listing.
