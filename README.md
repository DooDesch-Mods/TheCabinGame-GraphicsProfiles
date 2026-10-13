# CabinGraphicsProfiles

> 🛟 **Need help or found a bug?** Get support at [support.doodesch.de/graphicsprofiles](https://support.doodesch.de/graphicsprofiles).

Offers Balanced and Performance profiles for GI, shadows, reflections and effects, plus Restore previous. **Graphics Profiles - Custom** adds manual graphics and display settings, including postprocessing, view distance, motion blur, depth of field, lens flare, chromatic aberration, bloom, sharpening and fog.

Requires [UE4SS 3.0.1 or later](https://www.nexusmods.com/thecabingame/mods/4). Install UE4SS separately.

1. Close the game and install UE4SS in your game folder.
2. Copy `Mods/CabinGraphicsProfiles` into `the_cabin_game/Binaries/Win64/ue4ss/Mods`.
3. Copy the archive's `the_cabin_game/Content/Paks/~mods` files to the same path in your game folder. Keep the three container files together.

Use [Mod Settings](https://www.nexusmods.com/thecabingame/mods/6) to choose a profile or **Restore previous** from its menu. The ZIP also includes `README.profile_templates.json` for manual configuration. No profile is applied on startup.

For manual settings, select **Graphics Profiles - Custom**, change the controls, then press **Apply**. **Cancel** discards pending edits. The panel reads the current game values; presets still change only their four quality groups. Custom effect overrides persist across restarts and the game's own graphics Apply. Use **Restore previous custom settings** to restore the values from before the last custom Apply, including the earlier overrides. The matching Mod Settings update is required for integer sliders.

Display resolution, window mode, render scale, FPS limit, V-Sync and color blind settings use the game's saved graphics options. Particle Detail matches the original menu's saved option, which currently has no effect in the base game. The proposed `r.SpecularScale` and `r.RoughnessMode` variables are unavailable on the tested build and are not exposed as working controls.

Use **Restore previous** to undo a profile or **Restore previous custom settings** to undo the last custom Apply before removal. Then close the game and remove only `Mods/CabinGraphicsProfiles` and its three named container files. Back up `Scripts/settings.dat`, `Scripts/previous_graphics.dat`, `Scripts/custom_overrides.dat` and `Scripts/previous_custom.dat` to retain stored preferences and previous values.

## Build and release

Tested baseline: Steam build `25553694`, Unreal 5.5 and UE4SS `v3.0.1-1164-g5e627997`.

Use Python 3.13. Run `python -m pip install -r requirements-dev.txt`, `python -m unittest discover -s tests -v`, `python tests/check_lua.py`, then `python tools/package.py`.

The builder writes a deterministic ZIP and checksum in `dist`. Overlay containers are committed build inputs; CI packages them and does not cook Unreal assets or download the game. Runtime Lua and containers are covered by the acceptance fingerprint. `python tools/package.py --release` rejects a missing or stale product acceptance. Multiplayer and a separate isolated gameplay session are explicitly not applicable to this local graphics provider.

CI checks Linux and Windows. See [publishing](docs/publishing.md) for the GitHub/Nexus flow and [Nexus description](docs/nexus.md) for the prepared listing.
