--[[
    AmbientLayer — Base Class for Ambient Audio Layers
    ───────────────────────────────────────────────
    Provides the reusable foundation for environment, wildlife, and
    custom ambient layers. Each layer manages its own set of sounds,
    responds to an update tick, and cleans up on shutdown.

    Subclassing pattern:
        local AmbientLayer = require(path.to.AmbientLayer)
        local MyLayer = setmetatable({}, { __index = AmbientLayer })
        function MyLayer:init() ... end
        function MyLayer:update(dt, context) ... end
]]

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local AmbientLayer = {}
AmbientLayer.__index = AmbientLayer

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

export type LayerContext = {
    playerPos: Vector3,
    timeOfDay: number,        -- 0..1 (0 = midnight, 0.5 = noon)
    intensity: number,        -- 0..1 global intensity (weather, combat, etc.)
    deltaTime: number,        -- seconds since last update
}

----------------------------------------------------------------
-- CONSTRUCTOR
----------------------------------------------------------------

--[[
    Create a new AmbientLayer instance.
    @param name string — layer name (used for folder/debug)
    @param parent Instance? — parent container (default: Workspace)
    @return AmbientLayer
]]
function AmbientLayer.new(name: string, parent: Instance?)
    local self = setmetatable({}, AmbientLayer)
    self.name = name or "AmbientLayer"
    self.parent = parent or Workspace
    self.sounds: { [string]: Sound } = {}
    self.initialized = false
    self.folder: Instance? = nil
    return self
end

----------------------------------------------------------------
-- INTERNAL HELPERS
----------------------------------------------------------------

local function createSound(name: string, parentId: Instance, assetId: string, looping: boolean, volume: number): Sound
    local snd = Instance.new("Sound")
    snd.Name = name
    snd.SoundId = assetId
    snd.Looped = looping
    snd.Volume = volume
    snd.Parent = parentId
    return snd
end

local function lerp(a: number, b: number, t: number): number
    return a + (b - a) * t
end

local function tweenVolume(snd: Sound, target: number, fadeTime: number)
    TweenService:Create(snd, TweenInfo.new(fadeTime), { Volume = target }):Play()
end

----------------------------------------------------------------
-- PUBLIC API (override in subclasses)
----------------------------------------------------------------

--[[
    Initialize the layer. Creates a folder and any persistent sounds.
    Override in subclass. Call self:_initBase() to set up the folder.
]]
function AmbientLayer:init()
    if self.initialized then return end
    self.folder = Instance.new("Folder")
    self.folder.Name = self.name
    self.folder.Parent = self.parent
    self.initialized = true
end

--[[
    Per-frame or per-tick update. Override in subclass.
    @param context LayerContext
]]
function AmbientLayer:update(context: LayerContext)
    -- Base implementation is a no-op. Subclasses implement logic.
end

----------------------------------------------------------------
-- PUBLIC HELPERS (available to subclasses)
----------------------------------------------------------------

--[[
    Create and register a looping ambient sound under this layer's folder.
    @param name string
    @param assetId string
    @param volume number
    @return Sound
]]
function AmbientLayer:addLoop(name: string, assetId: string, volume: number): Sound
    local snd = createSound(name, self.folder, assetId, true, volume)
    self.sounds[name] = snd
    snd:Play()
    return snd
end

--[[
    Create and register a sound (not auto-played) under this layer's folder.
    @param name string
    @param assetId string
    @param volume number
    @param looping boolean
    @return Sound
]]
function AmbientLayer:addSound(name: string, assetId: string, volume: number, looping: boolean): Sound
    local snd = createSound(name, self.folder, assetId, looping, volume)
    self.sounds[name] = snd
    return snd
end

--[[
    Play a one-shot sound from this layer's sound registry.
    @param name string — registered sound name
    @param volumeOverride number?
    @param pitchOverride number?
]]
function AmbientLayer:playOneShot(name: string, volumeOverride: number?, pitchOverride: number?)
    local snd = self.sounds[name]
    if not snd then return end
    if volumeOverride then snd.Volume = volumeOverride end
    if pitchOverride then snd.PlaybackSpeed = pitchOverride end
    snd:Play()
end

--[[
    Smoothly tween a registered sound's volume.
    @param name string
    @param target number
    @param fadeTime number — seconds (default 1.0)
]]
function AmbientLayer:tweenVol(name: string, target: number, fadeTime: number?)
    local snd = self.sounds[name]
    if not snd then return end
    tweenVolume(snd, target, fadeTime or 1.0)
end

--[[
    Crossfade between two registered sounds.
    @param fromName string
    @param toName string
    @param fadeTime number — seconds (default 2.0)
]]
function AmbientLayer:crossfade(fromName: string, toName: string, fadeTime: number?)
    local from = self.sounds[fromName]
    local to = self.sounds[toName]
    if from then tweenVolume(from, 0, fadeTime or 2.0) end
    if to then
        to:Play()
        tweenVolume(to, to.Volume, fadeTime or 2.0)
    end
end

--[[
    Static utility: lerp function exposed for subclasses.
]]
AmbientLayer.lerp = lerp

--[[
    Clean up all sounds and the folder.
]]
function AmbientLayer:cleanup()
    for _, snd in pairs(self.sounds) do
        snd:Stop()
        snd:Destroy()
    end
    self.sounds = {}
    if self.folder then
        self.folder:Destroy()
        self.folder = nil
    end
    self.initialized = false
end

return AmbientLayer
