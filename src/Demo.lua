--[[
    Demo — Roblox Audio Suite Integration Demo
    ───────────────────────────────────────────────
    Shows all layers working together:
      • AudioManager core mixer with config
      • MusicDirector mood transitions
      • EnvironmentAudio weather-driven ambient
      • WildlifeAudio creature spawning
      • UIAudio interface feedback

    Wire this into a server Script or StarterPlayerScripts.
    Press keys to trigger events (client-side demo).

    Setup:
        Place this script in StarterPlayerScripts (LocalScript)
        or require it from a server Script.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local src = script.Parent

local AudioManager = require(src.AudioManager)
local MusicDirector = require(src.MusicDirector)
local EnvironmentAudio = require(src.EnvironmentAudio)
local WildlifeAudio = require(src.WildlifeAudio)
local UIAudio = require(src.UIAudio)

----------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------

local DEMO_CONFIG = {
    -- AudioManager config
    crossfadeTime = 3.0,
    maxConcurrent = 32,
    groups = { "ambient", "sfx", "music", "ui" },

    -- Looping ambient bed sounds
    ambient = {
        wind = {
            soundId = "rbxassetid://6455667685",
            volume = 0.10,
            looped = true,
        },
    },

    -- Music modes
    music = {
        exploration = {
            soundId = "rbxassetid://145485235",
            volume = 0.25,
            looped = true,
        },
        combat = {
            soundId = "rbxassetid://528689056",
            volume = 0.30,
            looped = true,
        },
        victory = {
            soundId = "rbxassetid://1836029595",
            volume = 0.25,
            looped = true,
        },
    },

    -- Random ambient one-shots
    randomAmbient = {
        {
            def = { soundId = "rbxassetid://9120832471", volume = 0.25 },
            weight = 0.45,
            minDelay = 15,
            maxDelay = 45,
        },
        {
            def = { soundId = "rbxassetid://9118858002", volume = 0.20 },
            weight = 0.35,
            minDelay = 30,
            maxDelay = 90,
        },
    },
}

----------------------------------------------------------------
-- MUSIC MOODS (stem-based)
----------------------------------------------------------------

local DEMO_MOODS = {
    calm = {
        { id = "rbxassetid://145485235",   role = "melody",  volume = 0.25 },
        { id = "rbxassetid://9116245410",  role = "harmony", volume = 0.18 },
    },
    tense = {
        { id = "rbxassetid://528689056",   role = "melody",  volume = 0.30 },
        { id = "rbxassetid://314428418",   role = "harmony", volume = 0.25 },
        { id = "rbxassetid://9120917974",  role = "rhythm",  volume = 0.28 },
    },
    triumphant = {
        { id = "rbxassetid://1836029595",  role = "melody",  volume = 0.32 },
        { id = "rbxassetid://4342630136",  role = "harmony", volume = 0.25 },
    },
    silence = {},
}

----------------------------------------------------------------
-- INITIALIZE ALL SYSTEMS
----------------------------------------------------------------

local function initAll()
    -- Core mixer
    AudioManager.init(DEMO_CONFIG)

    -- Music director with moods
    MusicDirector.init(DEMO_MOODS)

    -- Ambient layers
    EnvironmentAudio:init()
    WildlifeAudio:init()
    UIAudio:init()

    -- Start with calm mood
    MusicDirector.setMood("calm")

    print("[AudioSuite Demo] All systems initialized.")
    print("[AudioSuite Demo] Controls:")
    print("  [1] = Play SFX at random position")
    print("  [2] = Switch music to 'tense'")
    print("  [3] = Switch music to 'triumphant'")
    print("  [4] = Switch music to 'calm'")
    print("  [5] = Increase weather intensity")
    print("  [6] = Decrease weather intensity")
    print("  [7] = Play UI sound")
    print("  [8] = Spawn wildlife event")
    print("  [9] = Duck/restore music")
    print("  [0] = Shutdown all audio")
end

----------------------------------------------------------------
-- UPDATE LOOP (for ambient layers)
----------------------------------------------------------------

local function startUpdateLoop()
    local player = Players.LocalPlayer

    RunService.Heartbeat:Connect(function(dt)
        if not player or not player.Character then return end
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local context = {
            playerPos = hrp.Position,
            timeOfDay = 0.4,  -- midday for demo purposes
            intensity = AudioManager.getIntensity(),
            deltaTime = dt,
        }

        EnvironmentAudio:update({
            windSpeed = 20 + context.intensity * 60,
            precipitation = context.intensity * 0.8,
            fogLevel = 0.1,
            intensity = context.intensity,
            isDaytime = true,
        })

        WildlifeAudio:update(context)
    end)
end

----------------------------------------------------------------
-- INPUT HANDLERS (demo controls)
----------------------------------------------------------------

local musicDucked = false

local function setupInput()
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        local key = input.KeyCode.Name

        if key == "One" then
            local pos = Vector3.new(math.random(-50, 50), 0, math.random(-50, 50))
            AudioManager.playSfx({
                soundId = "rbxassetid://9120832471",
                volume = 0.5,
            }, pos)
            print("[Demo] SFX at", pos)

        elseif key == "Two" then
            MusicDirector.setMood("tense")
            AudioManager.setMusic("combat")

        elseif key == "Three" then
            MusicDirector.setMood("triumphant")
            AudioManager.setMusic("victory")

        elseif key == "Four" then
            MusicDirector.setMood("calm")
            AudioManager.setMusic("exploration")

        elseif key == "Five" then
            local newLevel = math.clamp(AudioManager.getIntensity() + 0.2, 0, 1)
            AudioManager.setIntensity(newLevel)
            print("[Demo] Intensity:", newLevel)

        elseif key == "Six" then
            local newLevel = math.clamp(AudioManager.getIntensity() - 0.2, 0, 1)
            AudioManager.setIntensity(newLevel)
            print("[Demo] Intensity:", newLevel)

        elseif key == "Seven" then
            local sounds = { "click", "confirm", "success", "achievement" }
            UIAudio:play(sounds[math.random(1, #sounds)])

        elseif key == "Eight" then
            local creatures = { "bird", "whale", "porpoise", "splash" }
            WildlifeAudio:spawnEvent(creatures[math.random(1, #creatures)])
            print("[Demo] Wildlife spawned")

        elseif key == "Nine" then
            if musicDucked then
                MusicDirector.restoreStems()
                AudioManager.restoreMusic()
                print("[Demo] Music restored")
            else
                MusicDirector.duckStems(0.3)
                AudioManager.duckMusic(0.3)
                print("[Demo] Music ducked")
            end
            musicDucked = not musicDucked

        elseif key == "Zero" then
            print("[Demo] Shutting down all audio...")
            MusicDirector.cleanup()
            EnvironmentAudio:cleanup()
            WildlifeAudio:cleanup()
            UIAudio:cleanup()
            AudioManager.shutdown()
        end
    end)
end

----------------------------------------------------------------
-- BOOT
----------------------------------------------------------------

initAll()
startUpdateLoop()
setupInput()

-- Auto-cycle weather every 30 seconds for demo
task.spawn(function()
    while true do
        task.wait(30)
        if EnvironmentAudio.initialized then
            local level = math.random()
            AudioManager.setIntensity(level)
            print("[Demo] Auto weather → intensity", level)
        end
    end
end)
