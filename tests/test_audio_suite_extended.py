"""
Extended tests for roblox-audio-suite — AmbientLayer base class,
EnvironmentAudio, UIAudio, WildlifeAudio module structure.
Overnight creative loop.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from conftest import LuaRunner

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
runner = LuaRunner.shared()


def load_ambient():
    return runner.strip_and_load(os.path.join(REPO, "src", "AmbientLayer.lua"), "AmbientLayer")

def load_env():
    return runner.strip_and_load(os.path.join(REPO, "src", "EnvironmentAudio.lua"), "EnvironmentAudio")

def load_ui():
    return runner.strip_and_load(os.path.join(REPO, "src", "UIAudio.lua"), "UIAudio")

def load_wildlife():
    return runner.strip_and_load(os.path.join(REPO, "src", "WildlifeAudio.lua"), "WildlifeAudio")


class TestAmbientLayerStructure:
    def test_module_is_table(self):
        code = load_ambient() + 'io.write(type(AmbientLayer))'
        assert runner.run(code).strip() == "table"

    def test_has_new(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.new))'
        assert runner.run(code).strip() == "function"

    def test_has_init(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.init))'
        assert runner.run(code).strip() == "function"

    def test_has_update(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.update))'
        assert runner.run(code).strip() == "function"

    def test_has_addLoop(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.addLoop))'
        assert runner.run(code).strip() == "function"

    def test_has_addSound(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.addSound))'
        assert runner.run(code).strip() == "function"

    def test_has_playOneShot(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.playOneShot))'
        assert runner.run(code).strip() == "function"

    def test_has_tweenVol(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.tweenVol))'
        assert runner.run(code).strip() == "function"

    def test_has_crossfade(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.crossfade))'
        assert runner.run(code).strip() == "function"

    def test_has_cleanup(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.cleanup))'
        assert runner.run(code).strip() == "function"

    def test_has_lerp(self):
        code = load_ambient() + 'io.write(type(AmbientLayer.lerp))'
        assert runner.run(code).strip() == "function"

    def test_has_index_field(self):
        """AmbientLayer.__index should be set for subclassing."""
        code = load_ambient() + """
io.write(tostring(AmbientLayer.__index ~= nil))
"""
        assert runner.run(code).strip() == "true"


class TestAmbientLayerNew:
    def test_new_returns_table_with_name(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("TestLayer")
io.write(tostring(layer.name))
"""
        assert runner.run(code).strip() == "TestLayer"

    def test_new_default_name(self):
        code = load_ambient() + """
local layer = AmbientLayer.new()
io.write(tostring(layer.name))
"""
        assert runner.run(code).strip() == "AmbientLayer"

    def test_new_has_sounds_table(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
io.write(type(layer.sounds))
"""
        assert runner.run(code).strip() == "table"

    def test_new_not_initialized(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
io.write(tostring(layer.initialized))
"""
        assert runner.run(code).strip() == "false"

    def test_new_has_nil_folder(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
io.write(tostring(layer.folder))
"""
        assert runner.run(code).strip() == "nil"


class TestAmbientLayerLerp:
    def test_lerp_at_start(self):
        code = load_ambient() + """
io.write(tostring(AmbientLayer.lerp(0, 100, 0)))
"""
        assert runner.run(code).strip() == "0"

    def test_lerp_at_end(self):
        code = load_ambient() + """
io.write(tostring(AmbientLayer.lerp(0, 100, 1)))
"""
        assert runner.run(code).strip() == "100"

    def test_lerp_at_midpoint(self):
        code = load_ambient() + """
io.write(tostring(AmbientLayer.lerp(0, 100, 0.5)))
"""
        assert runner.run(code).strip() == "50"

    def test_lerp_negative_range(self):
        code = load_ambient() + """
io.write(tostring(AmbientLayer.lerp(-10, 10, 0.5)))
"""
        assert runner.run(code).strip() == "0"

    def test_lerp_clamps_beyond_1(self):
        """lerp doesn't clamp — t > 1 extrapolates."""
        code = load_ambient() + """
local result = AmbientLayer.lerp(0, 10, 2)
io.write(tostring(result))
"""
        assert runner.run(code).strip() == "20"


class TestAmbientLayerInit:
    def test_init_sets_initialized_true(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
io.write(tostring(layer.initialized))
"""
        assert runner.run(code).strip() == "true"

    def test_init_creates_folder(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("TestLayer")
layer:init()
io.write(tostring(layer.folder ~= nil))
"""
        assert runner.run(code).strip() == "true"

    def test_init_double_init_is_noop(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
layer:init()
io.write(tostring(layer.initialized))
"""
        assert runner.run(code).strip() == "true"


class TestAmbientLayerCleanup:
    def test_cleanup_resets_initialized(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
layer:cleanup()
io.write(tostring(layer.initialized))
"""
        assert runner.run(code).strip() == "false"

    def test_cleanup_sets_folder_nil(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
layer:cleanup()
io.write(tostring(layer.folder))
"""
        assert runner.run(code).strip() == "nil"

    def test_cleanup_clears_sounds(self):
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
layer:cleanup()
local count = 0
for _ in pairs(layer.sounds) do count = count + 1 end
io.write(tostring(count))
"""
        assert runner.run(code).strip() == "0"


class TestAmbientLayerPlayOneShot:
    def test_playOneShot_missing_sound_no_crash(self):
        """playOneShot on non-existent sound should not crash."""
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
layer:playOneShot("nonexistent")
io.write("ok")
"""
        assert runner.run(code).strip() == "ok"

    def test_tweenVol_missing_sound_no_crash(self):
        """tweenVol on non-existent sound should not crash."""
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
layer:tweenVol("nonexistent", 0.5, 1.0)
io.write("ok")
"""
        assert runner.run(code).strip() == "ok"

    def test_crossfade_missing_sounds_no_crash(self):
        """crossfade on non-existent sounds should not crash."""
        code = load_ambient() + """
local layer = AmbientLayer.new("Test")
layer:init()
layer:crossfade("a", "b", 1.0)
io.write("ok")
"""
        assert runner.run(code).strip() == "ok"


class TestEnvironmentAudio:
    def test_module_is_table(self):
        code = load_env() + 'io.write(type(EnvironmentAudio))'
        assert runner.run(code).strip() == "table"

    def test_module_has_metatable(self):
        """EnvironmentAudio should inherit from AmbientLayer."""
        code = load_env() + """
local mt = getmetatable(EnvironmentAudio)
io.write(tostring(mt ~= nil))
"""
        assert runner.run(code).strip() == "true"


class TestUIAudio:
    def test_module_is_table(self):
        code = load_ui() + 'io.write(type(UIAudio))'
        assert runner.run(code).strip() == "table"


class TestWildlifeAudio:
    def test_module_is_table(self):
        code = load_wildlife() + 'io.write(type(WildlifeAudio))'
        assert runner.run(code).strip() == "table"

    def test_has_metatable(self):
        """WildlifeAudio should inherit from AmbientLayer."""
        code = load_wildlife() + """
local mt = getmetatable(WildlifeAudio)
io.write(tostring(mt ~= nil))
"""
        assert runner.run(code).strip() == "true"
