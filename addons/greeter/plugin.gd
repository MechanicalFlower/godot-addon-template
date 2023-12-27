## Template Addon Plugin
@tool
extends EditorPlugin


## Return the plugin name
func get_plugin_name():
	return "Greeter"


## Just print a hello message
func _enter_tree():
	print("Hello John!")


## Just print a goodbye message
func _exit_tree():
	print("Goodbye John!")
