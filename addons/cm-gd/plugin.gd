@tool
extends EditorPlugin

var splash_inspector_plugin: EditorInspectorPlugin

func _enable_plugin() -> void:
	# Print welcome message
	print_rich("————————————————————————————————————————————\n")
	print_rich("[img=0x35]res://addons/cm-gd/editor/assets/cm_logo.png[/img]")
	print_rich("[font_size=20]Welcome to CM.gd![/font_size]")
	print_rich("Thank you for checking out CM.gd, here are some of the useful resources you can check out!\n")
	print_rich("↗ Documentation [url]https://cmgd.dev/[/url]")
	print_rich("↗ Discord [url]https://discord.gg/KrqmuQzxKK[/url]")
	print_rich("↗ Report Issues [url]https://github.com/maji-git/cm-gd/issues[/url]")
	print_rich("\nHappy Developing! 🧡")
	print_rich("\n————————————————————————————————————————————")

func _disable_plugin() -> void:
	pass

func _enter_tree() -> void:
	splash_inspector_plugin = preload("res://addons/cm-gd/editor/scripts/splash_inspector_plugin.gd").new()
	add_inspector_plugin(splash_inspector_plugin)

func _exit_tree() -> void:
	remove_inspector_plugin(splash_inspector_plugin)
