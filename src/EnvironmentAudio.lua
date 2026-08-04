--[[
    EnvironmentAudio — Weather & Biome Ambient Layer
    ───────────────────────────────────────────────
    Dynamic environment sounds that respond to weather state:
    layered wind, rain, wave/biome crossfades, thunder with distance
    delay, fog signals, and periodic ambient bells.

    Built on AmbientLayer for clean lifecycle management.

    Usage:
        local EnvironmentAudio = require(path.to.EnvironmentAudio)
        EnvironmentAudio:init()
        EnvironmentAudio:update({
            windSpeed = 40,
            precipitation = 0.5,
            fogLevel = 0.2,
            intensity = 0.3,
        })
        EnvironmentAudio:playThunder(500)  -- lightning 500 studs away
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local AmbientLayer = require(script.Parent.AmbientLayer)

local EnvironmentAudio = setmetatable({}, { __index = AmbientLayer })

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

export type WeatherState = {
    windSpeed: number,       -- studs/sec
    precipitation: number,   -- 0..1
    fogLevel: number,        -- 0..1
    intensity: number,       -- 0..1 (storm intensity)
    isDaytime: boolean?,
}

----------------------------------------------------------------
-- CONFIG (override before init)
----------------------------------------------------------------

EnvironmentAudio.config = {
    -- Base volumes
    baseVolume = 0.3,
    stormVolume = 0.55,
    windBaseVol = 0.15,
    windMaxVol = 0.45,
    windBasePitch = 0.85,
    windMaxPitch = 1.4,
    rainMaxVol = 0.35,
    thunderBaseVol = 0.6,
    fogSignalVol = 0.25,
    fogSignalInterval = 30,   -- seconds
    bellMinDelay = 8,
    bellMaxDelay = 25,
    bellVol = 0.15,

    -- Sound assets (replace with your own)
    assets = {
        base    = "rbxassetid://9112979210",  -- calm ambient bed
        storm   = "rbxassetid://9112979211",  -- storm ambient bed
        wind    = "rbxassetid://9112979212",
        rain    = "rbxassetid://9112979213",
        thunder = "rbxassetid://9112979214",
        fogSignal = "rbxassetid://9112979215",
        bell    = "rbxassetid://9112979216",
    },
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------

local initialized = false
local lastFogSignal = 0
local nextBellRing = 0
local thunderQueue: { { time: number, distance: number } } = {}

----------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------

function EnvironmentAudio:init()
    if initialized then return end
    AmbientLayer.init(self)
    self.name = "EnvironmentAudio"

    local cfg = self.config
    local assets = cfg.assets

    self:addLoop("Base",    assets.base,    cfg.baseVolume)
    self:addLoop("Storm",   assets.storm,   0)
    self:addLoop("Wind",    assets.wind,    cfg.windBaseVol)
    self:addLoop("Rain",    assets.rain,    0)
    self:addSound("Thunder",   assets.thunder,   cfg.thunderBaseVol, false)
    self:addSound("FogSignal", assets.fogSignal, cfg.fogSignalVol,  false)
    self:addSound("Bell",      assets.bell,      cfg.bellVol,       false)

    nextBellRing = os.clock() + math.random(cfg.bellMinDelay, cfg.bellMaxDelay)
    initialized = true
    print("[EnvironmentAudio] Initialized")
end

----------------------------------------------------------------
-- UPDATE
----------------------------------------------------------------

function EnvironmentAudio:update(state: WeatherState)
    if not initialized then return end

    local cfg = self.config
    local storm = state.intensity
    local lerp = AmbientLayer.lerp

    -- Base/storm bed crossfade
    self:tweenVol("Base",  lerp(cfg.baseVolume, 0, storm), 2)
    self:tweenVol("Storm", lerp(0, cfg.stormVolume, storm), 2)

    -- Wind: pitch and volume by wind speed
    local windNorm = math.clamp(state.windSpeed / 80, 0, 1)
    if self.sounds.Wind then
        self.sounds.Wind.PlaybackSpeed = lerp(cfg.windBasePitch, cfg.windMaxPitch, windNorm)
    end
    self:tweenVol("Wind", lerp(cfg.windBaseVol, cfg.windMaxVol, windNorm), 1)

    -- Rain: volume by precipitation
    self:tweenVol("Rain", state.precipitation * cfg.rainMaxVol, 1)

    -- Fog signal in foggy conditions
    local now = os.clock()
    if state.fogLevel > 0.3 and now - lastFogSignal > cfg.fogSignalInterval then
        lastFogSignal = now
        if self.sounds.FogSignal then
            self.sounds.FogSignal.Volume = cfg.fogSignalVol * state.fogLevel
            self.sounds.FogSignal:Play()
        end
    end

    -- Periodic bell rings
    if now > nextBellRing then
        nextBellRing = now + math.random(cfg.bellMinDelay, cfg.bellMaxDelay)
        if self.sounds.Bell then
            self.sounds.Bell.PlaybackSpeed = 0.9 + math.random() * 0.2
            self.sounds.Bell:Play()
        end
    end

    -- Process queued thunder (delayed by distance)
    local i = 1
    while i <= #thunderQueue do
        local entry = thunderQueue[i]
        if now >= entry.time then
            local distFactor = math.clamp(1.0 / (1.0 + entry.distance * 0.003), 0.05, 1)
            if self.sounds.Thunder then
                self.sounds.Thunder.Volume = cfg.thunderBaseVol * distFactor
                self.sounds.Thunder.PlaybackSpeed = lerp(1.2, 0.7, distFactor)
                self.sounds.Thunder:Play()
            end
            table.remove(thunderQueue, i)
        else
            i += 1
        end
    end
end

----------------------------------------------------------------
-- SPECIAL: THUNDER WITH DISTANCE DELAY
----------------------------------------------------------------

--[[
    Queue a thunder clap with distance-based delay and volume attenuation.
    @param distance number — studs from listener
]]
function EnvironmentAudio:playThunder(distance: number)
    if not initialized then return end
    local delay = distance * 0.0035  -- approx speed of sound scaling
    table.insert(thunderQueue, {
        time = os.clock() + delay,
        distance = distance,
    })
end

----------------------------------------------------------------
-- OVERRIDE CLEANUP
----------------------------------------------------------------

function EnvironmentAudio:cleanup()
    thunderQueue = {}
    lastFogSignal = 0
    nextBellRing = 0
    initialized = false
    AmbientLayer.cleanup(self)
    print("[EnvironmentAudio] Cleaned up")
end

return EnvironmentAudio
