@tool
extends Node

@onready var ver_label: Label = %VersionLabel

func _ready() -> void:
	ver_label.text = "v" + CM.VERSION
