# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-04

### Added
- **AudioManager** — core layered audio mixer with configurable SoundGroups, one-shot SFX (2D/3D), looping ambient beds, music crossfading, intensity-driven mixing, concurrent sound limiting, and duck/restore.
- **MusicDirector** — adaptive music system with mood-based stem crossfading. Each mood supports multiple stems (melody, harmony, rhythm) that fade independently. Runtime mood registration, duck/restore, and configurable default fade time.
- **AmbientLayer** — reusable base class for ambient audio layers. Provides lifecycle management, looping sound registration, volume tweening, crossfading, and a clean update context interface.
- **EnvironmentAudio** — weather-responsive ambient layer with base/storm bed crossfade, dynamic wind (pitch + volume), rain, distance-delayed thunder, fog signals, and periodic ambient bells. All parameters configurable via `config` table.
- **WildlifeAudio** — creature sound spawning layer with day/night probability tables, configurable per-creature definitions, hotspot zones for clustered spawning, 3D positioned playback, and manual event triggering.
- **UIAudio** — registry-driven interface sound system with looping sound support, pitch/volume overrides, runtime sound registration, and stop/stopAll with fades.
- **Demo** — interactive demo script showing all layers working together with keyboard controls and auto-cycling weather.
- **Rojo project file** (`default.project.json`) for syncing into Roblox Studio.
- **MIT license**.
- **Full documentation** with architecture diagram, API reference, sound asset guide, and quick start examples.
