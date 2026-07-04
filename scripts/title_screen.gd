extends Control

const MAIN_UI_PATH := "res://scenes/main_ui.tscn"
const SETTINGS_PANEL_SCENE := preload("res://scenes/settings_panel.tscn")

@onready var btn_new_game: Button = $RightButtons/BtnNewGame
@onready var btn_continue: Button = $RightButtons/BtnContinue
@onready var btn_settings: Button = $RightButtons/BtnSettings
@onready var btn_quit: Button = $RightButtons/BtnQuit

var _settings_panel: Control

func _ready() -> void:
	_settings_panel = SETTINGS_PANEL_SCENE.instantiate()
	_settings_panel.z_index = 200
	add_child(_settings_panel)

	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)

	var save_manager: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	btn_continue.disabled = save_manager == null or not save_manager.can_continue()

func _on_new_game_pressed() -> void:
	var save_manager: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if save_manager != null:
		save_manager.reset_progress()
		save_manager.boot_target = "home"
	get_tree().change_scene_to_file(MAIN_UI_PATH)

func _on_continue_pressed() -> void:
	var save_manager: SaveManager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	if save_manager != null:
		save_manager.boot_target = "continue"
	get_tree().change_scene_to_file(MAIN_UI_PATH)

func _on_settings_pressed() -> void:
	if _settings_panel != null and _settings_panel.has_method("open"):
		_settings_panel.call("open")

func _on_quit_pressed() -> void:
	get_tree().quit()
