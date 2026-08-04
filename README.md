# Roblox Audio Suite

A drop-in layered audio engine for immersive Roblox games. Provides music direction with mood-based stem crossfading, dynamic ambient layers (environment, wildlife, UI), distance-based 3D mixing, and a configurable core mixer.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     Your Game                           │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │     Demo     │  │  Your Script  │  │  Your UI     │  │
│  └──────┬───────┘  └──────┬────────┘  └──────┬───────┘  │
│         │                 │                   │          │
│  ═══════╪═════════════════╪═══════════════════╪════════ │
│         ▼                 ▼                   ▼          │
│  ┌────────────────────────────────────────────────────┐ │
│  │                  AudioManager                       │ │
│  │            (Core Mixer + Config Table)              │ │
│  │                                                     │ │
│  │  SoundGroups:  ambient │ sfx │ music │ ui │ custom │ │
│  │  Features:  one-shots, 3D positioning,             │ │
│  │              crossfades, intensity mixing,         │ │
│  │              concurrent limiting                   │ │
│  └───┬────────┬────────┬────────┬────────┬────────────┘ │
│      │        │        │        │        │               │
│      ▼        ▼        ▼        ▼        ▼               │
│  ┌──────┐┌──────┐┌──────────┐┌──────┐┌──────┐           │
│  │Music ││Music ││Environ-  ││Wild- ││ UI   │           │
│  │Director││&mixer││mentAudio││life  ││Audio │           │
│  │(moods)││(mode)││(weather)││Audio ││      │           │
│  └──────┘└──────┘└──────────┘└──────┘└──────┘           │
│      │                              │        │           │
│      ▼                              ▼        ▼           │
│  Melody/Harmony/Rhythm          Creature   Click/Alarm  │
│  Stem crossfades               spawning    Looping SFX   │
│                                                         │
│  ═══════════════════════════════════════════════════════ │
└─────────────────────────────────────────────────────────┘
```

## Quick Start

### Option 1: Rojo (recommended)

1. Clone this repo into your project:
   ```bash
   git clone https://github.com/SuperInstance/roblox-audio-suite.git
   ```

2. Add to your `default.project.json`:
   ```json
   {
     "name": "MyGame",
     "tree": {
       "$path": "src",
       "ReplicatedStorage": {
         "AudioSuite": {
           "$path": "roblox-audio-suite/src"
         }
       }
     }
   }
   ```

3. Use in your scripts:
   ```lua
   local AudioSuite = game.ReplicatedStorage.AudioSuite
   local AudioManager = require(AudioSuite.AudioManager)
   local MusicDirector = require(AudioSuite.MusicDirector)
   local UIAudio = require(AudioSuite.UIAudio)
   ```

### Option 2: Manual copy

Copy the `.lua` files from `src/` into your game as ModuleScripts under `ReplicatedStorage`.

## Components

### AudioManager (Core Mixer)

The central audio hub. Manages SoundGroups, one-shot SFX (2D and 3D), looping ambient beds, music crossfading, and intensity-driven mixing.

```lua
local AudioManager = require(AudioSuite.AudioManager)

AudioManager.init({
    crossfadeTime = 2.0,
    maxConcurrent = 32,
    groups = { "ambient", "sfx", "music", "ui" },
    ambient = {
        wind = { soundId = "rbxassetid://...", volume = 0.1, looped = true },
    },
    music = {
        exploration = { soundId = "rbxassetid://...", volume = 0.25, looped = true },
        combat = { soundId = "rbxassetid://...", volume = 0.30, looped = true },
    },
    randomAmbient = {
        {
            def = { soundId = "rbxassetid://...", volume = 0.25 },
            weight = 0.45,
            minDelay = 15,
            maxDelay = 45,
        },
    },
})

-- Play a 3D positioned SFX
AudioManager.playSfx({ soundId = "rbxassetid://...", volume = 0.5 }, somePosition)

-- Crossfade music
AudioManager.setMusic("combat")

-- Intensity-driven mixing (0 = calm, 1 = intense)
AudioManager.setIntensity(0.8)

-- Duck music during dialogue
AudioManager.duckMusic(0.3)
AudioManager.restoreMusic()

-- Group volume control
AudioManager.setGroupVolume("music", 0.5)
```

### MusicDirector (Adaptive Music)

Stem-based music system with named moods. Each mood has multiple stems (melody, harmony, rhythm) that crossfade independently.

```lua
local MusicDirector = require(AudioSuite.MusicDirector)

MusicDirector.init({
    calm = {
        { id = "rbxassetid://...", role = "melody",  volume = 0.25 },
        { id = "rbxassetid://...", role = "harmony", volume = 0.18 },
    },
    combat = {
        { id = "rbxassetid://...", role = "melody",  volume = 0.30 },
        { id = "rbxassetid://...", role = "rhythm",  volume = 0.28 },
    },
    silence = {},  -- fade everything out
})

MusicDirector.setMood("combat")
MusicDirector.transitionTo("calm", 5.0)  -- explicit fade time
MusicDirector.duckStems(0.3)             -- quiet during dialogue
MusicDirector.restoreStems()
```

### AmbientLayer (Base Class)

The reusable foundation for all ambient layers. Subclass it to create custom layers.

```lua
local AmbientLayer = require(AudioSuite.AmbientLayer)
local MyLayer = setmetatable({}, { __index = AmbientLayer })

function MyLayer:init()
    AmbientLayer.init(self)
    self:addLoop("Hum", "rbxassetid://...", 0.2)
end

function MyLayer:update(context)
    self:tweenVol("Hum", context.intensity * 0.5, 2.0)
end
```

### EnvironmentAudio (Weather & Biome)

Dynamic ambient layer that responds to weather state: wind, rain, base/storm crossfade, thunder with distance-based delay, fog signals.

```lua
local EnvironmentAudio = require(AudioSuite.EnvironmentAudio)

-- Customize assets before init
EnvironmentAudio.config.assets.wind = "rbxassetid://YOUR_WIND"
EnvironmentAudio.config.windMaxVol = 0.5

EnvironmentAudio:init()

-- Call every frame (or on weather update)
EnvironmentAudio:update({
    windSpeed = 40,
    precipitation = 0.5,
    fogLevel = 0.2,
    intensity = 0.3,
})

-- Thunder with distance delay
EnvironmentAudio:playThunder(500)
```

### WildlifeAudio (Creature Spawning)

Spawns positional creature sounds around the player based on time of day and probability tables.

```lua
local WildlifeAudio = require(AudioSuite.WildlifeAudio)

-- Register your own creatures
WildlifeAudio.config.creatures.cricket = {
    assetId = "rbxassetid://...",
    volume = 0.20,
    pitchRange = { 0.9, 1.1 },
    dayChance = 0.0,
    nightChance = 0.02,
    minDist = 10,
    maxDist = 50,
}

WildlifeAudio:init()

-- Per-tick update
WildlifeAudio:update({
    playerPos = character.PrimaryPart.Position,
    timeOfDay = 0.8,  -- evening
    intensity = 0.2,
    deltaTime = dt,
})

-- Manual trigger
WildlifeAudio:spawnEvent("bird")

-- Set hotspot zones
WildlifeAudio:setHotspots({ Vector3.new(100, 0, 50) })
```

### UIAudio (Interface Sounds)

Registry-driven UI sound system. Define named sounds, play them on demand, with looping support.

```lua
local UIAudio = require(AudioSuite.UIAudio)

-- Register custom sounds
UIAudio:registerSound("levelUp", {
    soundId = "rbxassetid://...",
    volume = 0.5,
    pitch = 1.2,
    loop = false,
    duration = 1.5,
})

UIAudio:init()
UIAudio:play("click")
UIAudio:play("alarm")    -- looping
UIAudio:stop("alarm")
UIAudio:stopAll()

-- Convenience
UIAudio:playWithPitch("click", 1.5)
UIAudio:playAtVolume("click", 0.2)
```

## API Reference

### AudioManager

| Method | Parameters | Description |
|--------|-----------|-------------|
| `init(config)` | `Config?` | Initialize with config table |
| `playSfx(def, position?, group?)` | `SoundDef, Vector3?, string?` | Play a one-shot SFX |
| `playAmbient(def, position?)` | `SoundDef, Vector3?` | Play on ambient bus |
| `setMusic(mode, fadeTime?)` | `string, number?` | Crossfade to a music mode |
| `getMusicMode()` | → `string?` | Current music mode |
| `setIntensity(level)` | `number (0-1)` | Set global intensity |
| `getIntensity()` | → `number` | Current intensity |
| `setGroupVolume(group, vol)` | `string, number` | Set SoundGroup volume |
| `getGroupVolume(group)` | → `number` | Get SoundGroup volume |
| `getGroup(group)` | → `SoundGroup?` | Get SoundGroup instance |
| `duckMusic(amount)` | `number (0-1)` | Duck music volume |
| `restoreMusic()` | | Restore music to config volume |
| `getActiveCount()` | → `number` | Active one-shot count |
| `getConfig()` | → `Config` | Get config table |
| `shutdown()` | | Full teardown |

### MusicDirector

| Method | Parameters | Description |
|--------|-----------|-------------|
| `init(moods?)` | `{ [Mood]: MoodDef }?` | Initialize with mood registry |
| `registerMood(mood, stems)` | `string, MoodDef` | Register/replace a mood |
| `setMood(mood)` | `string` | Switch mood (default fade) |
| `transitionTo(mood, fadeTime)` | `string, number` | Switch with explicit fade |
| `duckStems(amount)` | `number (0-1)` | Duck all stem volumes |
| `restoreStems()` | | Restore stem volumes |
| `getCurrentMood()` | → `string` | Current mood |
| `getStemCount()` | → `number` | Active stem count |
| `setFadeTime(seconds)` | `number` | Default transition fade |
| `cleanup()` | | Full teardown |

### AmbientLayer (base class)

| Method | Parameters | Description |
|--------|-----------|-------------|
| `.new(name, parent?)` | `string, Instance?` | Create instance |
| `:init()` | | Override for setup |
| `:update(context)` | `LayerContext` | Override for per-tick |
| `:addLoop(name, id, vol)` | `string, string, number` | Add looping sound |
| `:addSound(name, id, vol, loop)` | `string, string, number, boolean` | Add sound |
| `:playOneShot(name, vol?, pitch?)` | `string, number?, number?` | Play registered sound |
| `:tweenVol(name, target, time?)` | `string, number, number?` | Tween volume |
| `:crossfade(from, to, time?)` | `string, string, number?` | Crossfade two sounds |
| `:cleanup()` | | Destroy all sounds |

### EnvironmentAudio

Extends AmbientLayer. Override `config` before `init()`.

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:init()` | | Start environment layer |
| `:update(state)` | `WeatherState` | Per-tick weather update |
| `:playThunder(distance)` | `number` | Queue thunder with delay |

### WildlifeAudio

Extends AmbientLayer. Override `config.creatures` before `init()`.

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:init()` | | Start wildlife layer |
| `:update(context)` | `LayerContext` | Per-tick auto-spawning |
| `:spawnEvent(type, pos?)` | `string, Vector3?` | Manual creature spawn |
| `:setHotspots(zones)` | `{ Vector3 }` | Set cluster zones |
| `:registerCreature(type, def)` | `string, CreatureDef` | Register creature type |

### UIAudio

Extends AmbientLayer. Override `config.sounds` before `init()`.

| Method | Parameters | Description |
|--------|-----------|-------------|
| `:init()` | | Start UI audio |
| `:play(name)` | `string` | Play a UI sound |
| `:stop(name)` | `string` | Stop a looping sound |
| `:stopAll()` | | Stop all looping sounds |
| `:playWithPitch(name, pitch)` | `string, number` | Play with pitch override |
| `:playAtVolume(name, vol)` | `string, number` | Play with volume override |
| `:registerSound(name, cfg)` | `string, UISoundConfig` | Register sound type |

## Sound Asset Guide

All sound assets use Roblox audio asset IDs (`rbxassetid://...`). The suite ships with placeholder/demo IDs that are free Roblox catalog sounds. **Replace them with your own uploaded audio for production use.**

### Where to put assets

Each module has a `config` table you override before calling `init()`:

```lua
EnvironmentAudio.config.assets.wind = "rbxassetid://YOUR_WIND_ID"
EnvironmentAudio.config.assets.rain = "rbxassetid://YOUR_RAIN_ID"
```

### Recommended asset sources

- **Roblox Creator Marketplace** — upload your own `.mp3`/`.ogg` files
- **Freesound.org** — CC-licensed sound effects (convert to `.ogg`/`.mp3` before upload)
- **Kenney.nl** — CC0 game audio packs

### Asset naming conventions

| Category | Naming | Example |
|----------|--------|---------|
| Ambient loops | `amb_<name>_loop` | `amb_wind_loop` |
| SFX one-shots | `sfx_<name>` | `sfx_sword_hit` |
| Music stems | `mus_<mood>_<role>` | `mus_combat_melody` |
| UI sounds | `ui_<action>` | `ui_button_click` |

## Rojo Project

The included `default.project.json` maps the suite to `ReplicatedStorage.AudioSuite`:

```json
{
  "name": "RobloxAudioSuite",
  "tree": {
    "$className": "ReplicatedStorage",
    "AudioSuite": {
      "$path": "src"
    }
  }
}
```

## Demo

Run `Demo.lua` in `StarterPlayerScripts` to see all layers working together with keyboard controls:

| Key | Action |
|-----|--------|
| 1 | Play SFX at random 3D position |
| 2 | Switch music to "tense" |
| 3 | Switch music to "triumphant" |
| 4 | Switch music to "calm" |
| 5 | Increase weather intensity |
| 6 | Decrease weather intensity |
| 7 | Play random UI sound |
| 8 | Spawn wildlife event |
| 9 | Duck / restore music |
| 0 | Shutdown all audio |

## License

MIT — see [LICENSE](LICENSE).
