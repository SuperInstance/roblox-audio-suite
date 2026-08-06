"""
Comprehensive test suite for AudioSuite — Layered audio system.
Tests AudioManager init, SoundGroup management, one-shot playback,
music crossfade, intensity clamping, group volume, shutdown, MusicDirector.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from conftest import LuaRunner

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "src")
runner = LuaRunner.shared()


def load_am():
    return runner.strip_and_load(os.path.join(SRC, "AudioManager.lua"), "AudioManager")


def load_md():
    return runner.strip_and_load(os.path.join(SRC, "MusicDirector.lua"), "MusicDirector")


class TestAudioManagerInit:
    def test_module_is_table(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager))').strip() == "table"

    def test_init_creates_groups(self):
        code = load_am() + """
        AudioManager.init({})
        io.write(tostring(AudioManager.getGroup("sfx") ~= nil))
        """
        assert runner.run(code).strip() == "true"

    def test_double_init_safe(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.init({})
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_has_init(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.init))').strip() == "function"

    def test_has_playSfx(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.playSfx))').strip() == "function"

    def test_has_setMusic(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.setMusic))').strip() == "function"

    def test_has_shutdown(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.shutdown))').strip() == "function"


class TestSoundGroupManagement:
    def test_default_groups_created(self):
        code = load_am() + """
        AudioManager.init({})
        local r = ""
        for _, n in ipairs({"ambient","sfx","music","ui"}) do
            r = r .. tostring(AudioManager.getGroup(n) ~= nil) .. ","
        end
        io.write(r:sub(1,-2))
        """
        assert runner.run(code).strip() == "true,true,true,true"

    def test_custom_group(self):
        code = load_am() + """
        AudioManager.init({groups={"ambient","sfx","music","ui","voice"}})
        io.write(tostring(AudioManager.getGroup("voice") ~= nil))
        """
        assert runner.run(code).strip() == "true"

    def test_unknown_group_nil(self):
        code = load_am() + """
        AudioManager.init({})
        io.write(tostring(AudioManager.getGroup("nonexistent")))
        """
        assert runner.run(code).strip() == "nil"

    def test_set_group_volume(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setGroupVolume("sfx", 0.5)
        io.write(tostring(AudioManager.getGroupVolume("sfx")))
        """
        assert runner.run(code).strip() == "0.5"

    def test_group_volume_default(self):
        code = load_am() + """
        AudioManager.init({})
        io.write(tostring(AudioManager.getGroupVolume("sfx")))
        """
        assert runner.run(code).strip() == "1"

    def test_volume_clamped_high(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setGroupVolume("sfx", 5.0)
        io.write(tostring(AudioManager.getGroupVolume("sfx")))
        """
        assert runner.run(code).strip() == "1"

    def test_volume_clamped_low(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setGroupVolume("sfx", -5.0)
        io.write(tostring(AudioManager.getGroupVolume("sfx")))
        """
        assert runner.run(code).strip() == "0"

    def test_set_volume_unknown_group_safe(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setGroupVolume("nope", 0.5)
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"


class TestOneShotPlayback:
    def test_play_sfx_2d(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.playSfx({soundId="rbxassetid://123", volume=0.5})
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_play_sfx_3d(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.playSfx({soundId="rbxassetid://123", volume=0.5}, Vector3.new(10,0,0))
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_play_sfx_custom_group(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.playSfx({soundId="rbxassetid://123", volume=0.5}, nil, "ui")
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_play_ambient(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.playAmbient({soundId="rbxassetid://456", volume=0.3})
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"


class TestMusicCrossfade:
    def test_set_music_mode(self):
        code = load_am() + """
        AudioManager.init({music={exploration={soundId="rbxassetid://1",volume=0.3,looped=true}}})
        AudioManager.setMusic("exploration")
        io.write(tostring(AudioManager.getMusicMode()))
        """
        assert runner.run(code).strip() == "exploration"

    def test_set_music_same_noop(self):
        code = load_am() + """
        AudioManager.init({music={exp={soundId="rbxassetid://1",volume=0.3,looped=true}}})
        AudioManager.setMusic("exp")
        AudioManager.setMusic("exp")
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_set_music_none(self):
        code = load_am() + """
        AudioManager.init({music={exp={soundId="rbxassetid://1",volume=0.3,looped=true}}})
        AudioManager.setMusic("exp")
        AudioManager.setMusic("none")
        io.write(tostring(AudioManager.getMusicMode()))
        """
        assert runner.run(code).strip() == "none"

    def test_set_music_unknown(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setMusic("unknown")
        io.write(tostring(AudioManager.getMusicMode()))
        """
        assert runner.run(code).strip() == "nil"

    def test_duck_music_safe(self):
        code = load_am() + """
        AudioManager.init({music={exp={soundId="rbxassetid://1",volume=0.3,looped=true}}})
        AudioManager.setMusic("exp")
        AudioManager.duckMusic(0.3)
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_restore_music_safe(self):
        code = load_am() + """
        AudioManager.init({music={exp={soundId="rbxassetid://1",volume=0.3,looped=true}}})
        AudioManager.setMusic("exp")
        AudioManager.duckMusic(0.3)
        AudioManager.restoreMusic()
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"


class TestIntensity:
    def test_initial_zero(self):
        code = load_am() + """
        AudioManager.init({})
        io.write(tostring(AudioManager.getIntensity()))
        """
        assert runner.run(code).strip() == "0"

    def test_set_half(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setIntensity(0.5)
        io.write(tostring(AudioManager.getIntensity()))
        """
        assert runner.run(code).strip() == "0.5"

    def test_clamped_high(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setIntensity(2.0)
        io.write(tostring(AudioManager.getIntensity()))
        """
        assert runner.run(code).strip() == "1"

    def test_clamped_low(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setIntensity(-1.0)
        io.write(tostring(AudioManager.getIntensity()))
        """
        assert runner.run(code).strip() == "0"

    def test_set_zero(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setIntensity(0.7)
        AudioManager.setIntensity(0.0)
        io.write(tostring(AudioManager.getIntensity()))
        """
        assert runner.run(code).strip() == "0"


class TestShutdown:
    def test_shutdown_safe(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.shutdown()
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_shutdown_resets_music(self):
        code = load_am() + """
        AudioManager.init({music={t={soundId="rbxassetid://1",volume=0.3,looped=true}}})
        AudioManager.setMusic("t")
        AudioManager.shutdown()
        io.write(tostring(AudioManager.getMusicMode()))
        """
        assert runner.run(code).strip() == "nil"

    def test_shutdown_resets_intensity(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.setIntensity(0.8)
        AudioManager.shutdown()
        io.write(tostring(AudioManager.getIntensity()))
        """
        assert runner.run(code).strip() == "0"

    def test_reinit_after_shutdown(self):
        code = load_am() + """
        AudioManager.init({})
        AudioManager.shutdown()
        AudioManager.init({})
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"


class TestAudioManagerStructure:
    def test_has_playAmbient(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.playAmbient))').strip() == "function"

    def test_has_getMusicMode(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.getMusicMode))').strip() == "function"

    def test_has_setIntensity(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.setIntensity))').strip() == "function"

    def test_has_getIntensity(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.getIntensity))').strip() == "function"

    def test_has_setGroupVolume(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.setGroupVolume))').strip() == "function"

    def test_has_getGroupVolume(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.getGroupVolume))').strip() == "function"

    def test_has_getActiveCount(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.getActiveCount))').strip() == "function"

    def test_has_getConfig(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.getConfig))').strip() == "function"

    def test_has_duckMusic(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.duckMusic))').strip() == "function"

    def test_has_restoreMusic(self):
        assert runner.run(load_am() + 'io.write(type(AudioManager.restoreMusic))').strip() == "function"


class TestMusicDirector:
    def test_module_is_table(self):
        assert runner.run(load_md() + 'io.write(type(MusicDirector))').strip() == "table"

    def test_init(self):
        assert runner.run(load_md() + 'MusicDirector.init()\nio.write("ok")').strip() == "ok"

    def test_initial_mood_silence(self):
        code = load_md() + 'MusicDirector.init()\nio.write(tostring(MusicDirector.getCurrentMood()))'
        assert runner.run(code).strip() == "silence"

    def test_initial_stem_count(self):
        code = load_md() + 'MusicDirector.init()\nio.write(tostring(MusicDirector.getStemCount()))'
        assert runner.run(code).strip() == "0"

    def test_register_and_transition(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.registerMood("combat", {{id="rbxassetid://1", role="rhythm", volume=0.5}})
        MusicDirector.transitionTo("combat", 0.5)
        io.write(tostring(MusicDirector.getCurrentMood()))
        """
        assert runner.run(code).strip() == "combat"

    def test_transition_same_noop(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.registerMood("calm", {{id="rbxassetid://1", role="melody", volume=0.3}})
        MusicDirector.transitionTo("calm", 0.5)
        MusicDirector.transitionTo("calm", 0.5)
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_transition_unknown_safe(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.transitionTo("nonexistent", 0.5)
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_set_mood_before_init_safe(self):
        code = load_md() + 'MusicDirector.setMood("test")\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_set_fade_time(self):
        code = load_md() + 'MusicDirector.init()\nMusicDirector.setFadeTime(5.0)\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_duck_stems_safe(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.registerMood("c", {{id="rbxassetid://1", role="r", volume=0.5}})
        MusicDirector.transitionTo("c", 0.5)
        MusicDirector.duckStems(0.3)
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_restore_stems_safe(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.registerMood("c", {{id="rbxassetid://1", role="r", volume=0.5}})
        MusicDirector.transitionTo("c", 0.5)
        MusicDirector.duckStems(0.3)
        MusicDirector.restoreStems()
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_cleanup_resets_mood(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.registerMood("c", {{id="rbxassetid://1", role="r", volume=0.5}})
        MusicDirector.transitionTo("c", 0.5)
        MusicDirector.cleanup()
        io.write(tostring(MusicDirector.getCurrentMood()))
        """
        assert runner.run(code).strip() == "silence"

    def test_cleanup_resets_stems(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.registerMood("c", {{id="rbxassetid://1", role="r", volume=0.5}})
        MusicDirector.transitionTo("c", 0.5)
        MusicDirector.cleanup()
        io.write(tostring(MusicDirector.getStemCount()))
        """
        assert runner.run(code).strip() == "0"

    def test_silent_mood_transition(self):
        code = load_md() + """
        MusicDirector.init()
        MusicDirector.registerMood("silence", {})
        MusicDirector.transitionTo("silence", 0.5)
        io.write(tostring(MusicDirector.getStemCount()))
        """
        assert runner.run(code).strip() == "0"
