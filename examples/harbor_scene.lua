-- examples/harbor_scene.lua
-- Full harbor audio environment using AudioSuite.
-- Place in StarterPlayerScripts (LocalScript).
--
-- Creates a complete soundscape for a coastal/harbor scene:
--   • Layered ocean ambience (base + wave swells)
--   • Wildlife: seabirds, porpoise calls, splashes
--   • UI feedback sounds wired to a basic interface
--   • Adaptive music: exploration → tension → calm
--
-- This demonstrates every AudioSuite module working together:
--   AudioManager (core mixer)
--   EnvironmentAudio (weather/ocean)
--   WildlifeAudio (creatures)
--   MusicDirector (adaptive music)
--   UIAudio (interface feedback)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AudioManager = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("AudioManager"))
local EnvironmentAudio = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("EnvironmentAudio"))
local WildlifeAudio = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("WildlifeAudio"))
local MusicDirector = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("MusicDirector"))
local UIAudio = require(ReplicatedStorage:WaitForChild("AudioSuite"):WaitForChild("UIAudio"))

local player = Players.LocalPlayer

-- ============================================================
--  1. Initialize AudioManager (the core mixer)
-- ============================================================

AudioManager.init({
    crossfadeTime = 3.0,
    maxConcurrent = 40,
    groups = { "ambient", "sfx", "music", "ui" },

    -- Looping ambient bed
    ambient = {
        ocean_base = {
            soundId = "rbxassetid://9112979210",
            volume = 0.30,
            looped = true,
        },
        ocean_swells = {
            soundId = "rbxassetid://9112979211",
            volume = 0.15,
            looped = true,
        },
    },

    -- Music modes (will be used by MusicDirector below)
    music = {
        exploration = {
            soundId = "rbxassetid://1837879082",
            volume = 0.20,
            looped = true,
        },
        tension = {
            soundId = "rbxassetid://1837879083",
            volume = 0.35,
            looped = true,
        },
        calm = {
            soundId = "rbxassetid://1837879084",
            volume = 0.18,
            looped = true,
        },
    },

    -- Random ambient one-shots (distant foghorn, creaking docks)
    randomAmbient = {
        {
            def = { soundId = "rbxassetid://9112979215", volume = 0.25, looped = false },
            weight = 1,
            minDelay = 25,
            maxDelay = 60,
        },
        {
            def = { soundId = "rbxassetid://9112979216", volume = 0.15, looped = false },
            weight = 2,
            minDelay = 15,
            maxDelay = 40,
        },
    },
})

print("[Harbor Scene] AudioManager initialized")

-- ============================================================
--  2. Environment Audio (weather + ocean dynamics)
-- ============================================================

EnvironmentAudio:init()

-- Configure with harbor-appropriate assets
EnvironmentAudio.config.assets = {
    base      = "rbxassetid://9112979210",  -- calm sea bed
    storm     = "rbxassetid://9112979211",  -- storm surge
    wind      = "rbxassetid://9112979212",  -- harbor wind
    rain      = "rbxassetid://9112979213",  -- rain on water
    thunder   = "rbxassetid://9112979214",  -- distant thunder
    fogSignal = "rbxassetid://9112979215",  -- lighthouse foghorn
    bell      = "rbxassetid://9112979216",  -- harbor bell
}

-- Update loop for weather dynamics
RunService.Heartbeat:Connect(function()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Simulate a calm harbor with gentle weather
    EnvironmentAudio:update({
        windSpeed = 15,
        precipitation = 0.0,
        fogLevel = 0.3,     -- harbor fog
        intensity = 0.0,    -- calm
        isDaytime = true,
    })
end)

print("[Harbor Scene] Environment audio started (calm harbor)")

-- ============================================================
--  3. Wildlife Audio (seabirds, porpoises, splashes)
-- ============================================================

WildlifeAudio:init()

-- Register harbor-specific creatures
WildlifeAudio.config.creatures.seagull = {
    assetId = "rbxassetid://9112979220",
    variations = {
        "rbxassetid://9112979220",
        "rbxassetid://9112979221",
    },
    volume = 0.25,
    pitchRange = { 0.9, 1.3 },
    dayChance = 0.02,
    nightChance = 0.0,
    minDist = 25,
    maxDist = 90,
}

WildlifeAudio.config.creatures.porpoise = {
    assetId = "rbxassetid://9112979223",
    volume = 0.30,
    pitchRange = { 0.8, 1.1 },
    dayChance = 0.003,
    nightChance = 0.001,
    minDist = 40,
    maxDist = 120,
}

-- Set hotspot near the harbor entrance
WildlifeAudio:setHotspots({
    Vector3.new(0, 0, -50),   -- harbor mouth
    Vector3.new(30, 0, -40),  -- rocky point
})

-- Update wildlife based on player position
RunService.Heartbeat:Connect(function()
    local character = player.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    WildlifeAudio:update({
        playerPos = hrp.Position,
        timeOfDay = 0.4,  -- daytime
        deltaTime = 0.016,
    })
end)

print("[Harbor Scene] Wildlife audio started (gulls, porpoises)")

-- ============================================================
--  4. Music Director (adaptive music with mood transitions)
-- ============================================================

MusicDirector.init({
    exploration = {
        { id = "rbxassetid://1837879082", role = "melody", volume = 0.15 },
        { id = "rbxassetid://1837879085", role = "harmony", volume = 0.10 },
    },
    tension = {
        { id = "rbxassetid://1837879083", role = "melody", volume = 0.25 },
        { id = "rbxassetid://1837879086", role = "rhythm", volume = 0.20 },
    },
    calm = {
        { id = "rbxassetid://1837879084", role = "melody", volume = 0.12 },
    },
})

MusicDirector.setFadeTime(4.0)  -- slow, atmospheric transitions

-- Start with exploration music
MusicDirector.setMood("exploration")
print("[Harbor Scene] Music: exploration mode")

-- Simulate mood changes based on game events
task.delay(15, function()
    print("[Harbor Scene] Storm approaching → tension music")
    MusicDirector.transitionTo("tension", 3.0)

    -- Increase environment intensity
    RunService.Heartbeat:Connect(function()
        EnvironmentAudio:update({
            windSpeed = 45,
            precipitation = 0.4,
            fogLevel = 0.5,
            intensity = 0.6,
            isDaytime = false,
        })
    end)

    -- Lightning strike with thunder
    task.delay(3, function()
        EnvironmentAudio:playThunder(300)  -- 300 studs away
        print("[Harbor Scene] ⚡ Lightning + thunder (300 studs)")
    end)
end)

task.delay(35, function()
    print("[Harbor Scene] Storm passing → calm music")
    MusicDirector.transitionTo("calm", 5.0)
end)

-- ============================================================
--  5. UI Audio (interface feedback)
-- ============================================================

UIAudio:init()

-- Register a custom harbor-specific UI sound
UIAudio:registerSound("anchor_drop", {
    soundId = "rbxassetid://314428418",
    volume = 0.40,
    pitch = 0.6,
    loop = false,
    duration = 0.8,
})

-- Wire up to a basic interaction
local function setupInteractionGui()
    local PlayerGui = player:WaitForChild("PlayerGui")

    local gui = Instance.new("ScreenGui")
    gui.Name = "HarborUI"
    gui.ResetOnSpawn = false
    gui.Parent = PlayerGui

    -- Button: Drop Anchor
    local btn = Instance.new("TextButton")
    btn.Name = "DropAnchorButton"
    btn.Size = UDim2.new(0, 140, 0, 40)
    btn.Position = UDim2.new(0.02, 0, 0.02, 0)
    btn.Text = "⚓ Drop Anchor"
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
    btn.TextColor3 = Color3.fromRGB(200, 210, 220)
    btn.Parent = gui

    btn.MouseEnter:Connect(function()
        UIAudio:play("hover")
    end)

    btn.MouseButton1Down:Connect(function()
        UIAudio:play("click")
        UIAudio:play("anchor_drop")
        print("[Harbor Scene] ⚓ Anchor dropped!")

        -- Duck music briefly for the impact
        MusicDirector.duckStems(0.4)
        task.delay(1.5, function()
            MusicDirector.restoreStems()
        end)
    end)

    -- Button: Toggle Music
    local musicBtn = Instance.new("TextButton")
    musicBtn.Name = "MusicToggle"
    musicBtn.Size = UDim2.new(0, 140, 0, 40)
    musicBtn.Position = UDim2.new(0.02, 0, 0.08, 0)
    musicBtn.Text = "🎵 Toggle Music"
    musicBtn.Font = Enum.Font.Gotham
    musicBtn.TextSize = 14
    musicBtn.BackgroundColor3 = Color3.fromRGB(40, 50, 60)
    musicBtn.TextColor3 = Color3.fromRGB(200, 210, 220)
    musicBtn.Parent = gui

    local musicOn = true
    musicBtn.MouseButton1Down:Connect(function()
        UIAudio:play("click")
        if musicOn then
            AudioManager.setMusic("none", 1.0)
            musicOn = false
        else
            AudioManager.setMusic("exploration", 2.0)
            musicOn = true
        end
    end)
end

setupInteractionGui()
print("[Harbor Scene] UI audio wired up")

print("[Harbor Scene] 🌊 Full harbor audio initialized — enjoy the soundscape!")
