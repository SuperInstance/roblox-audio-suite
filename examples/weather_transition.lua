-- examples/weather_transition.lua
-- Crossfading audio layers during a weather change.
-- Place in StarterPlayerScripts (LocalScript).
--
-- Simulates a smooth weather transition from clear → stormy → clearing
-- over ~30 seconds, demonstrating:
--   • EnvironmentAudio crossfading base ↔ storm beds
--   • Wind pitch/volume responding to wind speed
--   • Rain fading in and out with precipitation level
--   • Thunder with realistic distance-based delay
--   • MusicDirector ducking during heavy weather
--   • WildlifeAudio going silent during the storm

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local EnvironmentAudio = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("EnvironmentAudio"))
local WildlifeAudio = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("WildlifeAudio"))
local MusicDirector = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("MusicDirector"))

local player = Players.LocalPlayer

-- ============================================================
--  Initialize layers
-- ============================================================

-- Environment: start with calm weather
EnvironmentAudio:init()
EnvironmentAudio.config.baseVolume = 0.35
EnvironmentAudio.config.stormVolume = 0.55

-- Wildlife: birds active in clear weather
WildlifeAudio:init()
WildlifeAudio.config.creatures.bird.dayChance = 0.02
WildlifeAudio.config.creatures.bird.nightChance = 0.0

-- Music: calm exploration stem
MusicDirector.init({
    calm = {
        { id = "rbxassetid://1837879084", role = "melody", volume = 0.18 },
    },
    storm = {
        { id = "rbxassetid://1837879083", role = "melody", volume = 0.25 },
        { id = "rbxassetid://1837879086", role = "rhythm", volume = 0.15 },
    },
})
MusicDirector.setFadeTime(6.0)
MusicDirector.setMood("calm")

print("[Weather Transition] Starting clear weather scene")

-- ============================================================
--  Weather state machine
-- ============================================================

local weather = {
    phase = "clear",      -- "clear" → "building" → "storm" → "clearing" → "clear"
    intensity = 0.0,      -- 0 = clear, 1 = full storm
    windSpeed = 10,       -- studs/sec
    precipitation = 0.0,  -- 0..1
    fogLevel = 0.1,
    timeOfDay = 0.4,      -- daytime
}

-- Smoothly interpolate weather values toward targets
local targets = {
    intensity = 0.0,
    windSpeed = 10,
    precipitation = 0.0,
    fogLevel = 0.1,
}

local function setWeatherPhase(phase, intensity, wind, precip, fog)
    weather.phase = phase
    targets.intensity = intensity
    targets.windSpeed = wind
    targets.precipitation = precip
    targets.fogLevel = fog
    print(string.format("[Weather Transition] → Phase: %s (intensity=%.2f, wind=%d, precip=%.2f)",
        phase, intensity, wind, precip))
end

-- ============================================================
--  Update loop: interpolate + drive audio
-- ============================================================

local LERP_SPEED = 0.5  -- how fast weather transitions (higher = faster)

RunService.Heartbeat:Connect(function(dt)
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Smooth interpolation toward target values
    weather.intensity = weather.intensity + (targets.intensity - weather.intensity) * LERP_SPEED * dt
    weather.windSpeed = weather.windSpeed + (targets.windSpeed - weather.windSpeed) * LERP_SPEED * dt
    weather.precipitation = weather.precipitation + (targets.precipitation - weather.precipitation) * LERP_SPEED * dt
    weather.fogLevel = weather.fogLevel + (targets.fogLevel - weather.fogLevel) * LERP_SPEED * dt

    -- Drive environment audio with interpolated values
    EnvironmentAudio:update({
        windSpeed = weather.windSpeed,
        precipitation = weather.precipitation,
        fogLevel = weather.fogLevel,
        intensity = weather.intensity,
        isDaytime = weather.timeOfDay > 0.25 and weather.timeOfDay < 0.75,
    })

    -- Drive wildlife: suppress creatures during heavy weather
    local creatureActivity = 1.0 - weather.intensity
    WildlifeAudio:update({
        playerPos = hrp.Position,
        timeOfDay = weather.timeOfDay,
        deltaTime = dt,
    })

    -- Reduce bird chance as storm builds (set their dayChance dynamically)
    local baseChance = 0.02
    WildlifeAudio.config.creatures.bird.dayChance = baseChance * creatureActivity

    -- Fog signal becomes more frequent in heavy fog
    if weather.fogLevel > 0.5 then
        EnvironmentAudio.config.fogSignalInterval = 15  -- more frequent
    else
        EnvironmentAudio.config.fogSignalInterval = 30  -- normal
    end
end)

-- ============================================================
--  Lightning system: random strikes during storm phase
-- ============================================================

local function scheduleLightning()
    task.spawn(function()
        while weather.phase == "storm" or weather.phase == "building" do
            local waitTime = 3 + math.random() * 8  -- 3-11 seconds between strikes
            task.wait(waitTime)

            local distance = 100 + math.random() * 600  -- 100-700 studs
            EnvironmentAudio:playThunder(distance)

            -- Brief music duck on close strikes
            if distance < 200 then
                MusicDirector.duckStems(0.3)
                task.delay(2.0, function()
                    MusicDirector.restoreStems()
                end)
            end

            print(string.format("[Weather Transition] ⚡ Lightning strike (%d studs)", distance))
        end
    end)
end

-- ============================================================
--  Weather timeline
-- ============================================================

-- Phase 1: Clear (0-5s) — starting state
print("[Weather Transition] Phase: CLEAR — gentle breeze, birdsong")

-- Phase 2: Building (5s) — wind picks up, clouds gather
task.delay(5, function()
    setWeatherPhase("building", 0.3, 30, 0.1, 0.3)

    -- Transition music toward storm mode
    MusicDirector.transitionTo("storm", 8.0)

    -- Birds start going quiet
    print("[Weather Transition] Birds going quiet...")
end)

-- Phase 3: Full storm (12s) — heavy rain, strong wind, thunder
task.delay(12, function()
    setWeatherPhase("storm", 0.85, 55, 0.6, 0.5)
    scheduleLightning()

    print("[Weather Transition] 🌩️ Full storm — thunder, heavy rain, strong wind")
end)

-- Phase 4: Clearing (25s) — rain subsides, wind drops
task.delay(25, function()
    setWeatherPhase("clearing", 0.3, 20, 0.1, 0.2)

    -- Crossfade back to calm music
    MusicDirector.transitionTo("calm", 10.0)

    print("[Weather Transition] Storm clearing — rain tapering off")
end)

-- Phase 5: Clear again (35s) — back to peaceful
task.delay(35, function()
    setWeatherPhase("clear", 0.0, 10, 0.0, 0.1)
    print("[Weather Transition] ☀️ Clear skies — birdsong returns")
end)

print("[Weather Transition] Audio system ready — weather timeline started")
print("[Weather Transition] Full cycle: clear (5s) → building (7s) → storm (13s) → clearing (10s) → clear")
