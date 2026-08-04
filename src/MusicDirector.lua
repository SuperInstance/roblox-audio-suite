--[[
    MusicDirector — Adaptive Music with Mood Transitions
    ───────────────────────────────────────────────
    Stem-based music system that crossfades between named moods.
    Each mood can have multiple stems (melody, harmony, rhythm) that
    fade in/out independently, creating smooth adaptive transitions.

    Usage:
        local MusicDirector = require(path.to.MusicDirector)
        MusicDirector.init()
        MusicDirector.setMood("exploration")
        MusicDirector.transitionTo("combat", 3.0)
        MusicDirector.duckStems(0.3)  -- quiet during dialogue
        MusicDirector.restoreStems()
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MusicDirector = {}

----------------------------------------------------------------
-- TYPES
----------------------------------------------------------------

export type Mood = string

export type StemDef = {
    id: string,
    role: string,       -- "melody" | "harmony" | "rhythm" | "pad" | etc.
    volume: number,
}

export type MoodDef = { StemDef }

export type Stem = {
    sound: Sound,
    role: string,
    targetVolume: number,
}

----------------------------------------------------------------
-- STATE
----------------------------------------------------------------

local DEFAULT_FADE = 4.0
local STEM_FADE = 3.0

local musicFolder: Instance?
local currentMood: Mood = "silence"
local currentStems: { Stem } = {}
local initialized = false
local moodRegistry: { [Mood]: MoodDef } = {}
local customFadeTime: number? = nil

----------------------------------------------------------------
-- INTERNAL: FOLDER MANAGEMENT
----------------------------------------------------------------

local function getOrCreateFolder(): Instance
    if not musicFolder or not musicFolder.Parent then
        musicFolder = Instance.new("Folder")
        musicFolder.Name = "MusicDirector"
        musicFolder.Parent = SoundService
    end
    return musicFolder
end

----------------------------------------------------------------
-- INTERNAL: TWEEN HELPERS
----------------------------------------------------------------

local function fadeOutAndDestroy(snd: Sound, fadeTime: number)
    TweenService:Create(snd, TweenInfo.new(fadeTime), { Volume = 0 }):Play()
    task.delay(fadeTime + 0.2, function()
        if snd and snd.Parent then
            snd:Stop()
            snd:Destroy()
        end
    end)
end

local function fadeIn(snd: Sound, targetVolume: number, fadeTime: number)
    snd.Volume = 0
    snd:Play()
    TweenService:Create(snd, TweenInfo.new(fadeTime), { Volume = targetVolume }):Play()
end

local function randomizePlaybackSpeed(snd: Sound)
    -- Slight pitch variation to avoid obvious looping fatigue
    snd.PlaybackSpeed = 0.98 + math.random() * 0.04
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

--[[
    Initialize the MusicDirector.
    Optionally pass a mood registry to define moods programmatically.
    @param moods { [Mood]: MoodDef }? — mood name → array of stem defs
]]
function MusicDirector.init(moods: { [Mood]: MoodDef }?)
    getOrCreateFolder()
    if moods then
        moodRegistry = moods
    end
    initialized = true
    print("[MusicDirector] Initialized (mood: silence)")
end

--[[
    Register or replace a mood definition at runtime.
    @param mood Mood name
    @param stems MoodDef — array of stem definitions
]]
function MusicDirector.registerMood(mood: Mood, stems: MoodDef)
    moodRegistry[mood] = stems
end

--[[
    Set the default fade time for mood transitions.
    @param fadeTime number — seconds
]]
function MusicDirector.setFadeTime(fadeTime: number)
    customFadeTime = fadeTime
end

--[[
    Switch to a new mood with stem crossfading.
    @param mood Mood name (must be registered)
]]
function MusicDirector.setMood(mood: Mood)
    if not initialized then
        warn("[MusicDirector] Not initialized; call init() first")
        return
    end
    if mood == currentMood then return end
    MusicDirector.transitionTo(mood, customFadeTime or STEM_FADE)
end

--[[
    Transition to a new mood with explicit fade time.
    @param mood Mood name
    @param fadeTime number — seconds for crossfade
]]
function MusicDirector.transitionTo(mood: Mood, fadeTime: number)
    if not initialized then return end
    if mood == currentMood then return end

    local folder = getOrCreateFolder()
    local newStemData = moodRegistry[mood]

    if not newStemData then
        warn("[MusicDirector] Unknown mood:", mood)
        return
    end

    -- Fade out all current stems
    for _, stem in ipairs(currentStems) do
        fadeOutAndDestroy(stem.sound, fadeTime)
    end
    currentStems = {}

    -- Handle silence/empty moods
    if #newStemData == 0 then
        currentMood = mood
        print("[MusicDirector] Mood →", mood, "(silent)")
        return
    end

    -- Create and fade in new stems
    for _, data in ipairs(newStemData) do
        local snd = Instance.new("Sound")
        snd.Name = mood .. "_" .. data.role
        snd.SoundId = data.id
        snd.Looped = true
        snd.Parent = folder
        randomizePlaybackSpeed(snd)

        fadeIn(snd, data.volume, fadeTime)

        local stem: Stem = {
            sound = snd,
            role = data.role,
            targetVolume = data.volume,
        }
        table.insert(currentStems, stem)
    end

    currentMood = mood
    print("[MusicDirector] Mood →", mood, "(" .. #newStemData .. " stems)")
end

--[[
    Duck all stem volumes by a factor (e.g., during dialogue).
    @param amount number 0-1 (0 = silent, 1 = full volume)
]]
function MusicDirector.duckStems(amount: number)
    amount = math.clamp(amount, 0, 1)
    for _, stem in ipairs(currentStems) do
        TweenService:Create(stem.sound, TweenInfo.new(0.5), {
            Volume = stem.targetVolume * amount,
        }):Play()
    end
end

--[[
    Restore all stems to their target volumes.
]]
function MusicDirector.restoreStems()
    for _, stem in ipairs(currentStems) do
        TweenService:Create(stem.sound, TweenInfo.new(0.5), {
            Volume = stem.targetVolume,
        }):Play()
    end
end

--[[
    Get the currently active mood.
    @return Mood
]]
function MusicDirector.getCurrentMood(): Mood
    return currentMood
end

--[[
    Get the number of active stems.
    @return number
]]
function MusicDirector.getStemCount(): number
    return #currentStems
end

--[[
    Clean up all stems and reset to silence.
]]
function MusicDirector.cleanup()
    for _, stem in ipairs(currentStems) do
        stem.sound:Stop()
        stem.sound:Destroy()
    end
    currentStems = {}
    currentMood = "silence"
    if musicFolder then
        musicFolder:Destroy()
        musicFolder = nil
    end
    initialized = false
end

return MusicDirector
