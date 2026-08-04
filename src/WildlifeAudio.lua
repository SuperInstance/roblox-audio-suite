--[[
    WildlifeAudio — Creature Sound Spawning Layer
    ───────────────────────────────────────────────
    Spawns positional creature sounds around the player based on
    time of day, location, and configurable probability tables.
    Supports ambient auto-spawning and manual event triggering.

    Built on AmbientLayer for clean lifecycle management.

    Usage:
        local WildlifeAudio = require(path.to.WildlifeAudio)
        WildlifeAudio:init()
        WildlifeAudio:update({
            playerPos = character.PrimaryPart.Position,
            timeOfDay = 0.4,  -- daytime
            deltaTime = 0.016,
        })
        WildlifeAudio:spawnEvent("bird")
]]

local Workspace = game:GetService("Workspace")

local AmbientLayer = require(script.Parent.AmbientLayer)

local WildlifeAudio = setmetatable({}, { __index = AmbientLayer })

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

export type CreatureType = string

export type CreatureDef = {
    assetId: string,
    variations: { string }?,
    volume: number,
    pitchRange: { number, number },  -- {min, max}
    dayChance: number,
    nightChance: number,
    minDist: number,
    maxDist: number,
}

----------------------------------------------------------------
-- CONFIG (override before init)
----------------------------------------------------------------

WildlifeAudio.config = {
    max3dDist = 200,
    autoCleanupTime = 15,

    -- Register creatures here. Each has spawn probabilities.
    -- Override with your own asset IDs.
    creatures: { [CreatureType]: CreatureDef } = {
        bird = {
            assetId = "rbxassetid://9112979220",
            variations = {
                "rbxassetid://9112979220",
                "rbxassetid://9112979221",
                "rbxassetid://9112979222",
            },
            volume = 0.30,
            pitchRange = { 0.9, 1.2 },
            dayChance = 0.015,
            nightChance = 0.0,
            minDist = 20,
            maxDist = 80,
        },
        whale = {
            assetId = "rbxassetid://9112979223",
            volume = 0.40,
            pitchRange = { 0.8, 1.0 },
            dayChance = 0.0005,
            nightChance = 0.0008,
            minDist = 60,
            maxDist = 150,
        },
        porpoise = {
            assetId = "rbxassetid://9112979224",
            variations = {
                "rbxassetid://9112979224",
                "rbxassetid://9112979225",
            },
            volume = 0.25,
            pitchRange = { 1.0, 1.3 },
            dayChance = 0.003,
            nightChance = 0.001,
            minDist = 30,
            maxDist = 100,
        },
        splash = {
            assetId = "rbxassetid://9112979226",
            volume = 0.20,
            pitchRange = { 0.9, 1.2 },
            dayChance = 0.01,
            nightChance = 0.005,
            minDist = 10,
            maxDist = 60,
        },
    },

    -- Zones where creatures cluster (set at runtime)
    hotspots: { Vector3 } = {},
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------

local initialized = false

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------

local function pickRandom(list: { string }): string
    return list[math.random(1, #list)]
end

local function randomOffset(center: Vector3, minDist: number, maxDist: number): Vector3
    local angle = math.random() * math.pi * 2
    local dist = minDist + math.random() * (maxDist - minDist)
    return center + Vector3.new(
        math.cos(angle) * dist,
        0,
        math.sin(angle) * dist
    )
end

local function spawn3DSound(assetId: string, volume: number, pitch: number, position: Vector3, maxDist: number)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Position = position
    part.Parent = Workspace

    local snd = Instance.new("Sound")
    snd.SoundId = assetId
    snd.Volume = volume
    snd.PlaybackSpeed = pitch
    snd.Looped = false
    snd.RollOffMaxDistance = maxDist
    snd.RollOffMinDistance = 10
    snd.RollOffMode = Enum.RollOffMode.InverseTapered
    snd.Parent = part
    snd:Play()

    snd.Ended:Connect(function()
        if part and part.Parent then part:Destroy() end
    end)

    -- Safety cleanup
    task.delay(15, function()
        if part and part.Parent then part:Destroy() end
    end)
end

----------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------

function WildlifeAudio:init()
    if initialized then return end
    AmbientLayer.init(self)
    self.name = "WildlifeAudio"
    initialized = true
    print("[WildlifeAudio] Initialized")
end

----------------------------------------------------------------
-- UPDATE (per-tick ambient spawning)
----------------------------------------------------------------

function WildlifeAudio:update(context)
    if not initialized then return end

    local cfg = self.config
    local playerPos = context.playerPos
    local isDaytime = context.timeOfDay > 0.25 and context.timeOfDay < 0.75

    -- Roll for each creature type
    for creatureType, def in pairs(cfg.creatures) do
        local chance = isDaytime and def.dayChance or def.nightChance
        if chance > 0 and math.random() < chance then
            -- Pick origin: hotspot if available, else random offset
            local origin = playerPos
            if #cfg.hotspots > 0 and math.random() < 0.3 then
                origin = cfg.hotspots[math.random(1, #cfg.hotspots)]
            end

            local pos = randomOffset(origin, def.minDist, def.maxDist)
            local pitch = def.pitchRange[1] + math.random() * (def.pitchRange[2] - def.pitchRange[1])

            local assetId = def.assetId
            if def.variations and #def.variations > 0 then
                assetId = pickRandom(def.variations)
            end

            spawn3DSound(assetId, def.volume, pitch, pos, cfg.max3dDist)
        end
    end
end

----------------------------------------------------------------
-- MANUAL EVENT TRIGGER
----------------------------------------------------------------

--[[
    Manually spawn a creature sound (non-positional by default).
    @param creatureType CreatureType — must exist in config.creatures
    @param position Vector3? — optional 3D position
]]
function WildlifeAudio:spawnEvent(creatureType: CreatureType, position: Vector3?)
    if not initialized then return end
    local def = self.config.creatures[creatureType]
    if not def then
        warn("[WildlifeAudio] Unknown creature type:", creatureType)
        return
    end

    local pitch = def.pitchRange[1] + math.random() * (def.pitchRange[2] - def.pitchRange[1])
    local assetId = def.assetId
    if def.variations and #def.variations > 0 then
        assetId = pickRandom(def.variations)
    end

    if position then
        spawn3DSound(assetId, def.volume, pitch, position, self.config.max3dDist)
    else
        local snd = Instance.new("Sound")
        snd.SoundId = assetId
        snd.Volume = def.volume
        snd.PlaybackSpeed = pitch
        snd.Looped = false
        snd.Parent = self.folder
        snd:Play()
        snd.Ended:Connect(function() snd:Destroy() end)
        task.delay(self.config.autoCleanupTime, function()
            if snd and snd.Parent then snd:Destroy() end
        end)
    end
end

----------------------------------------------------------------
-- HOTSPOT MANAGEMENT
----------------------------------------------------------------

--[[
    Set hotspot zones where creatures cluster.
    @param zones { Vector3 }
]]
function WildlifeAudio:setHotspots(zones: { Vector3 })
    self.config.hotspots = zones
end

----------------------------------------------------------------
-- CREATURE REGISTRATION
----------------------------------------------------------------

--[[
    Register a new creature type at runtime.
    @param creatureType CreatureType
    @param def CreatureDef
]]
function WildlifeAudio:registerCreature(creatureType: CreatureType, def: CreatureDef)
    self.config.creatures[creatureType] = def
end

----------------------------------------------------------------
-- OVERRIDE CLEANUP
----------------------------------------------------------------

function WildlifeAudio:cleanup()
    self.config.hotspots = {}
    initialized = false
    AmbientLayer.cleanup(self)
    print("[WildlifeAudio] Cleaned up")
end

return WildlifeAudio
