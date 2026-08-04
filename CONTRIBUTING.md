# Contributing to Roblox Audio Suite

Thanks for your interest in improving the Audio Suite!

## Getting Started

1. **Fork & clone** the repo
2. Install [Rojo](https://rojo.space) for Studio sync
3. Run `rojo serve` to test all layers in Studio
4. Run the Demo.lua to verify interactive controls

## Development Workflow

```bash
rojo serve
```

### Running Tests

Tests live in `spec/` and use [TestEZ](https://github.com/Roblox/testez) format.

### Code Style

- **Luau type annotations** on all exported types and public functions
- **Doc comments** on all module-level APIs
- **camelCase** for methods, **PascalCase** for module tables
- All Sound instances must have explicit cleanup (Debris or explicit Destroy)
- Never leave orphaned carrier Parts in the workspace

## Architecture

The suite has four layers:

1. **AudioManager** (core) — SoundGroups, one-shot SFX, music crossfading, concurrent limiting
2. **MusicDirector** — stem-based adaptive music with mood crossfading
3. **AmbientLayer** (base class) — subclassed by EnvironmentAudio, WildlifeAudio, UIAudio
4. **Layer modules** — each manages its own folder, sounds, and update logic

All layers are **independent** — you can require just AudioManager, or just UIAudio, or any combination.

## Adding a New Ambient Layer

1. Create `src/MyLayer.lua`
2. Set metatable to AmbientLayer: `setmetatable({}, { __index = AmbientLayer })`
3. Override `:init()` and `:update(context)`
4. Register sounds via `self:addLoop()` / `self:addSound()`
5. Override `:cleanup()` to reset layer-specific state
6. Add config table for customization
7. Document in the README
8. Add to the Demo.lua

## Sound Asset Replacement

All sound IDs in the suite are placeholders (free Roblox catalog sounds). Consumers override them before `init()`:

```lua
EnvironmentAudio.config.assets.wind = "rbxassetid://YOUR_WIND_ID"
```

## Submitting Changes

1. Feature branch: `git checkout -b feat/your-feature`
2. Test cleanup: ensure `shutdown()` / `cleanup()` destroys all instances
3. Test nil guards: methods should handle missing Sound instances gracefully
4. Open a PR

## Reporting Bugs

Include:
- Which layer(s) were active
- What triggered the issue (key press, auto-update, shutdown)
- Whether sound IDs were overridden from defaults
- Error output from the Output panel

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
