--[[
    UIAudio — Interface Feedback Sounds
    ───────────────────────────────────────────────
    A registry-driven UI sound system. Define named sounds with
    volume, pitch, loop, and duration; play them on demand.
    Supports looping sounds (alarms, ambient UI loops) with
    explicit stop, pitch override, and volume override.

    Built on AmbientLayer for clean lifecycle management.

    Usage:
        local UIAudio = require(path.to.UIAudio)
        UIAudio:init()
        UIAudio:play("click")
        UIAudio:play("alarm")       -- looping
        UIAudio:stop("alarm")
        UIAudio:stopAll()
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local AmbientLayer = require(script.Parent.AmbientLayer)

local UIAudio = setmetatable({}, { __index = AmbientLayer })

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

export type SoundName = string

export type UISoundConfig = {
    soundId: string,
    volume: number,
    pitch: number,
    loop: boolean,
    duration: number,
}

----------------------------------------------------------------
-- CONFIG (override before init)
----------------------------------------------------------------

UIAudio.config = {
    sounds: {
        click       = { soundId = "rbxassetid://7212399604", volume = 0.35, pitch = 1.1,  loop = false, duration = 0.3 },
        hover       = { soundId = "rbxassetid://7212399604", volume = 0.15, pitch = 1.3,  loop = false, duration = 0.2 },
        open        = { soundId = "rbxassetid://9116245410", volume = 0.30, pitch = 1.0,  loop = false, duration = 0.5 },
        close       = { soundId = "rbxassetid://9116245410", volume = 0.25, pitch = 0.8,  loop = false, duration = 0.4 },
        confirm     = { soundId = "rbxassetid://4342630136", volume = 0.40, pitch = 1.0,  loop = false, duration = 0.6 },
        cancel      = { soundId = "rbxassetid://314428418",  volume = 0.35, pitch = 0.6,  loop = false, duration = 0.4 },
        error       = { soundId = "rbxassetid://314428418",  volume = 0.45, pitch = 0.4,  loop = false, duration = 0.5 },
        success     = { soundId = "rbxassetid://4342630136", volume = 0.55, pitch = 1.0,  loop = false, duration = 1.0 },
        notify      = { soundId = "rbxassetid://9116245410", volume = 0.35, pitch = 0.95, loop = false, duration = 0.5 },
        purchase    = { soundId = "rbxassetid://4342630136", volume = 0.50, pitch = 1.0,  loop = false, duration = 0.8 },
        achievement = { soundId = "rbxassetid://4342630136", volume = 0.55, pitch = 1.0,  loop = false, duration = 2.0 },
        alarm       = { soundId = "rbxassetid://9112979236", volume = 0.35, pitch = 1.3,  loop = true,  duration = 0.5 },
        warning     = { soundId = "rbxassetid://9112979237", volume = 0.45, pitch = 0.85, loop = true,  duration = 1.0 },
    },
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------

local activeLooping: { [string]: Sound } = {}

----------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------

function UIAudio:init()
    AmbientLayer.init(self)
    self.name = "UIAudio"
    self.folder.Parent = SoundService
    print("[UIAudio] Initialized")
end

----------------------------------------------------------------
-- PLAY
----------------------------------------------------------------

--[[
    Play a registered UI sound.
    @param name SoundName — key from config.sounds
    @return Sound? — the created sound instance
]]
function UIAudio:play(name: SoundName): Sound?
    local cfg = self.config.sounds[name]
    if not cfg then
        warn("[UIAudio] Unknown sound:", tostring(name))
        return nil
    end

    -- For looping sounds, stop previous instance first
    if cfg.loop then
        local existing = activeLooping[name]
        if existing then
            existing:Stop()
            existing:Destroy()
        end
    end

    local snd = Instance.new("Sound")
    snd.Name = name
    snd.SoundId = cfg.soundId
    snd.Volume = cfg.volume
    snd.PlaybackSpeed = cfg.pitch
    snd.Looped = cfg.loop
    snd.Parent = self.folder
    snd:Play()

    if cfg.loop then
        activeLooping[name] = snd
    else
        task.delay(cfg.duration + 0.5, function()
            if snd and snd.Parent then snd:Destroy() end
        end)
    end

    return snd
end

----------------------------------------------------------------
-- STOP
----------------------------------------------------------------

--[[
    Stop a looping UI sound with a quick fade.
    @param name SoundName
]]
function UIAudio:stop(name: SoundName)
    local snd = activeLooping[name]
    if snd then
        TweenService:Create(snd, TweenInfo.new(0.3), { Volume = 0 }):Play()
        task.delay(0.35, function()
            if snd and snd.Parent then
                snd:Stop()
                snd:Destroy()
            end
        end)
        activeLooping[name] = nil
    end
end

--[[
    Stop all looping UI sounds.
]]
function UIAudio:stopAll()
    for name, snd in pairs(activeLooping) do
        TweenService:Create(snd, TweenInfo.new(0.3), { Volume = 0 }):Play()
        task.delay(0.35, function()
            if snd and snd.Parent then
                snd:Stop()
                snd:Destroy()
            end
        end)
    end
    activeLooping = {}
end

----------------------------------------------------------------
-- CONVENIENCE
----------------------------------------------------------------

--[[
    Play a sound with a one-off pitch override.
    @param name SoundName
    @param pitch number
    @return Sound?
]]
function UIAudio:playWithPitch(name: SoundName, pitch: number): Sound?
    local snd = self:play(name)
    if snd then snd.PlaybackSpeed = pitch end
    return snd
end

--[[
    Play a sound with a one-off volume override.
    @param name SoundName
    @param volume number
    @return Sound?
]]
function UIAudio:playAtVolume(name: SoundName, volume: number): Sound?
    local snd = self:play(name)
    if snd then snd.Volume = volume end
    return snd
end

----------------------------------------------------------------
-- REGISTRATION
----------------------------------------------------------------

--[[
    Register or replace a UI sound at runtime.
    @param name SoundName
    @param cfg UISoundConfig
]]
function UIAudio:registerSound(name: SoundName, cfg: UISoundConfig)
    self.config.sounds[name] = cfg
end

----------------------------------------------------------------
-- CLEANUP
----------------------------------------------------------------

function UIAudio:cleanup()
    self:stopAll()
    AmbientLayer.cleanup(self)
    print("[UIAudio] Cleaned up")
end

return UIAudio
