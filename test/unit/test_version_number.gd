extends GutTest

func test_version_check() -> void:
	var cf := ConfigFile.new()
	cf.load("res://addons/cm-gd/plugin.cfg")
	var cf_ver = cf.get_value("plugin", "version")
	
	assert_eq(CM.VERSION, cf_ver)
