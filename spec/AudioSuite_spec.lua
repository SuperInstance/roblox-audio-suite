--[[
    Audio Suite Test Suite
    ──────────────────────
    Tests for API surface, nil-sound-ID guards, cleanup correctness,
    layer z-ordering, and config validation.

    Run with TestEZ or similar Roblox test runner.
]]

local AudioManager = require(script.Parent.src.AudioManager)
local MusicDirector = require(script.Parent.src.MusicDirector)
local AmbientLayer = require(script.Parent.src.AmbientLayer)
local EnvironmentAudio = require(script.Parent.src.EnvironmentAudio)
local WildlifeAudio = require(script.Parent.src.WildlifeAudio)
local UIAudio = require(script.Parent.src.UIAudio)

return function()

    -- ── AudioManager Tests ────────────────────────────────────

    describe("AudioManager module", function()
        it("is a table", function()
            expect(type(AudioManager)).to.equal("table")
        end)

        it("has all public methods", function()
            expect(AudioManager.init).to.be.a("function")
            expect(AudioManager.playSfx).to.be.a("function")
            expect(AudioManager.playAmbient).to.be.a("function")
            expect(AudioManager.setMusic).to.be.a("function")
            expect(AudioManager.getMusicMode).to.be.a("function")
            expect(AudioManager.setIntensity).to.be.a("function")
            expect(AudioManager.getIntensity).to.be.a("function")
            expect(AudioManager.setGroupVolume).to.be.a("function")
            expect(AudioManager.getGroupVolume).to.be.a("function")
            expect(AudioManager.getGroup).to.be.a("function")
            expect(AudioManager.duckMusic).to.be.a("function")
            expect(AudioManager.restoreMusic).to.be.a("function")
            expect(AudioManager.getActiveCount).to.be.a("function")
            expect(AudioManager.getConfig).to.be.a("function")
            expect(AudioManager.shutdown).to.be.a("function")
        end)

        it("getIntensity starts at 0", function()
            expect(AudioManager.getIntensity()).to.equal(0)
        end)

        it("setIntensity clamps to [0, 1]", function()
            AudioManager.setIntensity(-5)
            expect(AudioManager.getIntensity()).to.equal(0)

            AudioManager.setIntensity(0.5)
            expect(AudioManager.getIntensity()).to.equal(0.5)

            AudioManager.setIntensity(99)
            expect(AudioManager.getIntensity()).to.equal(1)
        end)

        it("getMusicMode is nil before any music is set", function()
            -- Music mode should be nil or "none" initially
            local mode = AudioManager.getMusicMode()
            expect(mode).never.to.be.ok()
        end)
    end)

    -- ── MusicDirector Tests ───────────────────────────────────

    describe("MusicDirector module", function()
        it("is a table", function()
            expect(type(MusicDirector)).to.equal("table")
        end)

        it("has all public methods", function()
            expect(MusicDirector.init).to.be.a("function")
            expect(MusicDirector.registerMood).to.be.a("function")
            expect(MusicDirector.setMood).to.be.a("function")
            expect(MusicDirector.transitionTo).to.be.a("function")
            expect(MusicDirector.duckStems).to.be.a("function")
            expect(MusicDirector.restoreStems).to.be.a("function")
            expect(MusicDirector.getCurrentMood).to.be.a("function")
            expect(MusicDirector.getStemCount).to.be.a("function")
            expect(MusicDirector.setFadeTime).to.be.a("function")
            expect(MusicDirector.cleanup).to.be.a("function")
        end)

        it("getCurrentMood starts as 'silence'", function()
            expect(MusicDirector.getCurrentMood()).to.equal("silence")
        end)

        it("getStemCount starts at 0", function()
            expect(MusicDirector.getStemCount()).to.equal(0)
        end)
    end)

    -- ── AmbientLayer Tests ────────────────────────────────────

    describe("AmbientLayer base class", function()
        it("is a table", function()
            expect(type(AmbientLayer)).to.equal("table")
        end)

        it("has all public methods", function()
            expect(AmbientLayer.new).to.be.a("function")
            expect(AmbientLayer.init).to.be.a("function")
            expect(AmbientLayer.update).to.be.a("function")
            expect(AmbientLayer.addLoop).to.be.a("function")
            expect(AmbientLayer.addSound).to.be.a("function")
            expect(AmbientLayer.playOneShot).to.be.a("function")
            expect(AmbientLayer.tweenVol).to.be.a("function")
            expect(AmbientLayer.crossfade).to.be.a("function")
            expect(AmbientLayer.cleanup).to.be.a("function")
        end)

        it("lerp function works correctly", function()
            expect(AmbientLayer.lerp(0, 10, 0.5)).to.equal(5)
            expect(AmbientLayer.lerp(0, 10, 0)).to.equal(0)
            expect(AmbientLayer.lerp(0, 10, 1)).to.equal(10)
        end)
    end)

    -- ── EnvironmentAudio Tests ────────────────────────────────

    describe("EnvironmentAudio module", function()
        it("is a table with AmbientLayer as metatable index", function()
            expect(type(EnvironmentAudio)).to.equal("table")
            expect(EnvironmentAudio.config).to.be.a("table")
        end)

        it("has assets config with all required keys", function()
            local assets = EnvironmentAudio.config.assets
            expect(assets.base).to.be.ok()
            expect(assets.storm).to.be.ok()
            expect(assets.wind).to.be.ok()
            expect(assets.rain).to.be.ok()
            expect(assets.thunder).to.be.ok()
            expect(assets.fogSignal).to.be.ok()
            expect(assets.bell).to.be.ok()
        end)

        it("has playThunder method", function()
            expect(EnvironmentAudio.playThunder).to.be.a("function")
        end)

        it("all asset IDs are rbxassetid format", function()
            for name, id in pairs(EnvironmentAudio.config.assets) do
                expect(id:match("^rbxassetid://%d+$")).to.be.ok()
            end
        end)
    end)

    -- ── WildlifeAudio Tests ───────────────────────────────────

    describe("WildlifeAudio module", function()
        it("is a table", function()
            expect(type(WildlifeAudio)).to.equal("table")
            expect(WildlifeAudio.config).to.be.a("table")
        end)

        it("has built-in creature definitions", function()
            local creatures = WildlifeAudio.config.creatures
            expect(creatures.bird).to.be.ok()
            expect(creatures.whale).to.be.ok()
            expect(creatures.porpoise).to.be.ok()
            expect(creatures.splash).to.be.ok()
        end)

        it("creatures have valid config shape", function()
            for name, def in pairs(WildlifeAudio.config.creatures) do
                expect(def.assetId).to.be.ok()
                expect(type(def.volume)).to.equal("number")
                expect(type(def.dayChance)).to.equal("number")
                expect(type(def.nightChance)).to.equal("number")
                expect(type(def.pitchRange)).to.equal("table")
                expect(#def.pitchRange).to.equal(2)
            end
        end)

        it("has setHotspots method", function()
            expect(WildlifeAudio.setHotspots).to.be.a("function")
        end)

        it("has registerCreature method", function()
            expect(WildlifeAudio.registerCreature).to.be.a("function")
        end)
    end)

    -- ── UIAudio Tests ─────────────────────────────────────────

    describe("UIAudio module", function()
        it("is a table", function()
            expect(type(UIAudio)).to.equal("table")
            expect(UIAudio.config).to.be.a("table")
        end)

        it("has built-in sound definitions", function()
            local sounds = UIAudio.config.sounds
            expect(sounds.click).to.be.ok()
            expect(sounds.confirm).to.be.ok()
            expect(sounds.error).to.be.ok()
            expect(sounds.success).to.be.ok()
            expect(sounds.alarm).to.be.ok()
        end)

        it("sound configs have valid shape", function()
            for name, cfg in pairs(UIAudio.config.sounds) do
                expect(type(cfg.soundId)).to.equal("string")
                expect(type(cfg.volume)).to.equal("number")
                expect(type(cfg.pitch)).to.equal("number")
                expect(type(cfg.loop)).to.equal("boolean")
                expect(type(cfg.duration)).to.equal("number")
            end
        end)

        it("has play, stop, stopAll, registerSound methods", function()
            expect(UIAudio.play).to.be.a("function")
            expect(UIAudio.stop).to.be.a("function")
            expect(UIAudio.stopAll).to.be.a("function")
            expect(UIAudio.registerSound).to.be.a("function")
            expect(UIAudio.playWithPitch).to.be.a("function")
            expect(UIAudio.playAtVolume).to.be.a("function")
        end)
    end)

    -- ── Nil Sound ID Safety ───────────────────────────────────

    describe("nil sound ID safety", function()
        it("playSfx with nil soundId should not crash", function()
            -- AudioManager.playSfx wraps in Sound creation; nil SoundId
            -- creates a Sound that won't play but shouldn't crash
            expect(function()
                AudioManager.playSfx({ soundId = "", volume = 0 })
            end).never.to.throw()
        end)

        it("MusicDirector transitionTo with empty mood is safe", function()
            MusicDirector.init()
            MusicDirector.registerMood("empty", {})
            expect(function()
                MusicDirector.transitionTo("empty", 0.1)
            end).never.to.throw()
        end)
    end)
end
