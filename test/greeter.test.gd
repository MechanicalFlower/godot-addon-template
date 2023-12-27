extends "res://addons/gut/test.gd"

const Plugin := preload("res://addons/freeter/plugin.gd")


func test_plugin():
    assert_eq(Plugin.get_plugin_name(), "Greeter")