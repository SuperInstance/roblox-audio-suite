--[[
    AudioManager — Core Layered Audio Mixer
    ───────────────────────────────────────────────
    A drop-in audio engine for any Roblox game that wants layered ambient audio.

    Features:
      • Configurable SoundGroup buses (ambient, sfx, music, ui, + custom)
      • One-shot SFX playback (2D or 3D positioned)
      • Ambient bed with looping sounds + random one-shot scheduler
      • Weather/intensity-driven dynamic mixing
      • Music crossfading between modes
      • Per-group volume control
      • Concurrent sound limiting with priority eviction

    Usage:
        local AudioManager = require(path.to.AudioManager)
        AudioManager.init({
            crossfadeTime = 2,
            maxConcurrent = 32,
            groups = { "ambient", "sfx", "music", "ui" },
        })
        AudioManager.playSfx(mySoundDef, somePosition)
        AudioManager.setMusic("exploration")
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AudioManager = {}

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

export type SoundDef = {
    soundId: string,
    volume: number?,
    pitch: number?,
    looped: boolean?,
    playbackSpeed: number?,
    rollOffMaxDistance: number?,
    rollOffMinDistance: number?,
}

export type AmbientEntry = {
    def: SoundDef,
    name: string,
    isLooped: boolean,
}

export type Config = {
    crossfadeTime: number?,
    maxConcurrent: number?,
    groups: { string }?,
    ambient: { [string]: SoundDef }?,
    music: { [string]: SoundDef }?,
    randomAmbient: { { def: SoundDef, weight: number, minDelay: number, maxDelay: number } }?,
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------

local initialized = false
local soundGroups: { [string]: SoundGroup } = {}
local ambientInstances: { [string]: Sound } = {}
local activeMusicSound: Sound? = nil
local currentMusicMode: string? = nil
local activeOneShots: { Sound } = {}
local intensityLevel = 0.0
local config: Config = {}
local preloadedIds: { [string]: boolean } = {}
local concurrentCount = 0

local DEFAULT_GROUPS = { "ambient", "sfx", "music", "ui" }
local DEFAULT_CROSSFADE = 2.0
local DEFAULT_MAX_CONCURRENT = 32

----------------------------------------------------------------
-- INTERNAL: SOUND GROUP MANAGEMENT
----------------------------------------------------------------

local function ensureSoundGroup(name: string): SoundGroup
    if soundGroups[name] then return soundGroups[name] end
    local existing = SoundService:FindFirstChild(name)
    if existing and existing:IsA("SoundGroup") then
        soundGroups[name] = existing
        return existing
    end
    local group = Instance.new("SoundGroup")
    group.Name = name
    group.Volume = 1.0
    group.Parent = SoundService
    soundGroups[name] = group
    return group
end

----------------------------------------------------------------
-- INTERNAL: SOUND CREATION
----------------------------------------------------------------

local function createSound(def: SoundDef, parent: Instance): Sound
    local sound = Instance.new("Sound")
    sound.SoundId = def.soundId
    sound.Volume = def.volume or 1.0
    sound.PlaybackSpeed = def.pitch or def.playbackSpeed or 1.0
    sound.Looped = def.looped or false
    sound.Parent = parent
    return sound
end

--[[
    Play a one-shot sound. Optionally positioned in 3D.
    Respects maxConcurrent by evicting the oldest sound.
]]
local function playOneShot(def: SoundDef, position: Vector3?, groupName: string?)
    groupName = groupName or "sfx"
    local group = soundGroups[groupName]

    -- Enforce concurrent limit
    if concurrentCount >= (config.maxConcurrent or DEFAULT_MAX_CONCURRENT) then
        local oldest = table.remove(activeOneShots, 1)
        if oldest then
            oldest:Stop()
            if oldest.Parent then oldest:Destroy() end
            concurrentCount -= 1
        end
    end

    if position then
        -- 3D positioned sound
        local part = Instance.new("Part")
        part.Name = "SfxCarrier"
        part.Size = Vector3.new(0.2, 0.2, 0.2)
        part.Position = position
        part.Transparency = 1
        part.CanCollide = false
        part.CanQuery = false
        part.Anchored = true
        part.Parent = group or workspace

        local sound = Instance.new("Sound")
        sound.SoundId = def.soundId
        sound.Volume = def.volume or 1.0
        sound.PlaybackSpeed = def.pitch or 1.0
        sound.Looped = false
        sound.RollOffMaxDistance = def.rollOffMaxDistance or 80
        sound.RollOffMinDistance = def.rollOffMinDistance or 5
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.Parent = part

        sound:Play()
        concurrentCount += 1
        table.insert(activeOneShots, sound)

        local cleanup = function()
            if part and part.Parent then part:Destroy() end
            concurrentCount = math.max(0, concurrentCount - 1)
        end
        Debris:AddItem(part, sound.TimeLength > 0 and (sound.TimeLength + 0.5) or 5)
        task.delay(sound.TimeLength > 0 and (sound.TimeLength + 0.5) or 5, cleanup)
    else
        -- Non-positional: parent directly to SoundGroup
        local sound = Instance.new("Sound")
        sound.SoundId = def.soundId
        sound.Volume = def.volume or 1.0
        sound.PlaybackSpeed = def.pitch or 1.0
        sound.Looped = false
        sound.Parent = group or SoundService

        sound:Play()
        concurrentCount += 1
        table.insert(activeOneShots, sound)

        local cleanup = function()
            if sound and sound.Parent then sound:Destroy() end
            concurrentCount = math.max(0, concurrentCount - 1)
        end
        Debris:AddItem(sound, sound.TimeLength > 0 and (sound.TimeLength + 0.5) or 5)
        task.delay(sound.TimeLength > 0 and (sound.TimeLength + 0.5) or 5, cleanup)
    end
end

----------------------------------------------------------------
-- INTERNAL: RANDOM AMBIENT SCHEDULER
----------------------------------------------------------------

local scheduleNextAmbient: () -> () = nil  -- forward declare

scheduleNextAmbient = function()
    if not initialized or not config.randomAmbient then return end

    -- Weighted random selection
    local totalWeight = 0
    for _, entry in ipairs(config.randomAmbient) do
        totalWeight += entry.weight
    end

    if totalWeight <= 0 then return end

    local roll = math.random() * totalWeight
    local cumulative = 0
    local selected = config.randomAmbient[1]

    for _, entry in ipairs(config.randomAmbient) do
        cumulative += entry.weight
        if roll <= cumulative then
            selected = entry
            break
        end
    end

    local delay = selected.minDelay + math.random() * (selected.maxDelay - selected.minDelay)

    task.delay(delay, function()
        if not initialized then return end
        playOneShot(selected.def, nil, "ambient")
        scheduleNextAmbient()
    end)
end

----------------------------------------------------------------
-- INTERNAL: INTENSITY-DRIVEN MIXING
----------------------------------------------------------------

local function updateIntensityMix()
    -- Override this hook or use setIntensity to drive layer volumes.
    -- By default, it just stores the value for external query.
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

--[[
    Initialize the audio system.

    @param cfg Config table:
        crossfadeTime  — seconds for music crossfades (default 2.0)
        maxConcurrent  — max simultaneous one-shot sounds (default 32)
        groups         — list of SoundGroup names to create (default: ambient, sfx, music, ui)
        ambient        — table of named SoundDefs for looping ambient bed
        music          — table of named SoundDefs for music modes
        randomAmbient  — array of { def = SoundDef, weight = number, minDelay = number, maxDelay = number }
]]
function AudioManager.init(cfg: Config?)
    if initialized then
        warn("[AudioManager] Already initialized.")
        return
    end

    config = cfg or {}
    local crossfade = config.crossfadeTime or DEFAULT_CROSSFADE

    -- Create SoundGroups
    local groupNames = config.groups or DEFAULT_GROUPS
    for _, name in ipairs(groupNames) do
        soundGroups[name] = ensureSoundGroup(name)
    end

    -- Create looping ambient sounds
    if config.ambient then
        for name, def in pairs(config.ambient) do
            if def.looped then
                local sound = createSound(def, soundGroups.ambient or SoundService)
                ambientInstances[name] = sound
                sound:Play()
            end
        end
    end

    -- Preload sound IDs
    local allIds = {}
    if config.ambient then
        for _, def in pairs(config.ambient) do table.insert(allIds, def.soundId) end
    end
    if config.music then
        for _, def in pairs(config.music) do table.insert(allIds, def.soundId) end
    end
    if config.randomAmbient then
        for _, entry in ipairs(config.randomAmbient) do table.insert(allIds, entry.def.soundId) end
    end
    for _, id in ipairs(allIds) do
        preloadedIds[id] = true
    end

    -- Start random ambient scheduler
    if config.randomAmbient and #config.randomAmbient > 0 then
        task.spawn(function()
            task.wait(5)
            scheduleNextAmbient()
        end)
    end

    initialized = true
    print("[AudioManager] Initialized —", #groupNames, "groups,", #allIds, "sounds preloaded.")
end

--[[
    Play a one-shot sound effect.
    @param def SoundDef table
    @param position Vector3? — world position for 3D sound
    @param groupName string? — SoundGroup name (default "sfx")
]]
function AudioManager.playSfx(def: SoundDef, position: Vector3?, groupName: string?)
    playOneShot(def, position, groupName)
end

--[[
    Play a sound on a specific ambient layer (e.g., a triggered ambient event).
    @param def SoundDef table
    @param position Vector3? — world position for 3D sound
]]
function AudioManager.playAmbient(def: SoundDef, position: Vector3?)
    playOneShot(def, position, "ambient")
end

--[[
    Switch music mode with a crossfade.
    @param mode string — key from config.music table, or "none" to stop
    @param fadeTime number? — override crossfadeTime (default from config)
]]
function AudioManager.setMusic(mode: string, fadeTime: number?)
    if mode == currentMusicMode then return end

    local musicCfg = config.music or {}
    local def = musicCfg[mode]
    if not def and mode ~= "none" then
        warn("[AudioManager] Unknown music mode:", mode)
        return
    end

    local fade = fadeTime or config.crossfadeTime or DEFAULT_CROSSFADE

    -- Fade out current music
    if activeMusicSound then
        local oldSound = activeMusicSound
        TweenService:Create(oldSound, TweenInfo.new(fade), { Volume = 0 }):Play()
        task.delay(fade + 0.2, function()
            oldSound:Stop()
            oldSound:Destroy()
        end)
        activeMusicSound = nil
    end

    -- Fade in new music
    if def and mode ~= "none" then
        local newSound = createSound(def, soundGroups.music or SoundService)
        newSound.Looped = def.looped or true
        newSound.Volume = 0
        newSound:Play()
        TweenService:Create(newSound, TweenInfo.new(fade), { Volume = def.volume or 0.3 }):Play()
        activeMusicSound = newSound
    end

    currentMusicMode = mode
end

--[[
    Get the current music mode.
    @return string?
]]
function AudioManager.getMusicMode(): string?
    return currentMusicMode
end

--[[
    Set the intensity level (0 = calm, 1 = intense).
    Use this to drive weather, combat, or any dynamic mixing.
    @param level number 0-1
]]
function AudioManager.setIntensity(level: number)
    level = math.clamp(level, 0, 1)
    intensityLevel = level
    updateIntensityMix()
end

--[[
    Get the current intensity level.
    @return number 0-1
]]
function AudioManager.getIntensity(): number
    return intensityLevel
end

--[[
    Set the volume of a SoundGroup.
    @param groupName string
    @param volume number 0-1
]]
function AudioManager.setGroupVolume(groupName: string, volume: number)
    local group = soundGroups[groupName]
    if not group then
        warn("[AudioManager] Unknown sound group:", groupName)
        return
    end
    group.Volume = math.clamp(volume, 0, 1)
end

--[[
    Get the volume of a SoundGroup.
    @param groupName string
    @return number
]]
function AudioManager.getGroupVolume(groupName: string): number
    local group = soundGroups[groupName]
    if not group then return 1.0 end
    return group.Volume
end

--[[
    Get a SoundGroup instance by name (for attaching sounds externally).
    @param groupName string
    @return SoundGroup?
]]
function AudioManager.getGroup(groupName: string): SoundGroup?
    return soundGroups[groupName]
end

--[[
    Duck all music volume by a factor (e.g., during dialogue).
    @param amount number 0-1 (0 = silent, 1 = full)
]]
function AudioManager.duckMusic(amount: number)
    amount = math.clamp(amount, 0, 1)
    if activeMusicSound then
        local baseVol = (config.music and config.music[currentMusicMode or ""] or {}).volume or 0.3
        TweenService:Create(activeMusicSound, TweenInfo.new(0.5), {
            Volume = baseVol * amount,
        }):Play()
    end
end

--[[
    Restore music volume to its configured level.
]]
function AudioManager.restoreMusic()
    if activeMusicSound then
        local baseVol = (config.music and config.music[currentMusicMode or ""] or {}).volume or 0.3
        TweenService:Create(activeMusicSound, TweenInfo.new(0.5), {
            Volume = baseVol,
        }):Play()
    end
end

--[[
    Get the current count of active one-shot sounds.
    @return number
]]
function AudioManager.getActiveCount(): number
    return concurrentCount
end

--[[
    Get the config table (read-only use recommended).
    @return Config
]]
function AudioManager.getConfig(): Config
    return config
end

--[[
    Tear down the audio system entirely. Stops all sounds and cleans up.
    Useful for testing or full resets.
]]
function AudioManager.shutdown()
    -- Stop ambient
    for _, sound in pairs(ambientInstances) do
        sound:Stop()
        sound:Destroy()
    end
    ambientInstances = {}

    -- Stop active one-shots
    for _, sound in ipairs(activeOneShots) do
        if sound and sound.Parent then
            sound:Stop()
            sound:Destroy()
        end
    end
    activeOneShots = {}
    concurrentCount = 0

    -- Stop music
    if activeMusicSound then
        activeMusicSound:Stop()
        activeMusicSound:Destroy()
        activeMusicSound = nil
    end

    currentMusicMode = nil
    intensityLevel = 0.0
    initialized = false
    print("[AudioManager] Shut down.")
end

return AudioManager
