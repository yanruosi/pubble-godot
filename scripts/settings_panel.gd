extends Control

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const KEY_MUSIC := "music_enabled"
const KEY_SFX := "sfx_enabled"

signal closed

@onready var _panel: PanelContainer = $Panel
@onready var _music_toggle: CheckButton = $Panel/Margin/VBox/MusicRow/MusicToggle
@onready var _sfx_toggle: CheckButton = $Panel/Margin/VBox/SfxRow/SfxToggle
@onready var _close_btn: Button = $Panel/Margin/VBox/CloseBtn

func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_settings()
	_close_btn.pressed.connect(_on_close_pressed)
	_music_toggle.toggled.connect(_on_music_toggled)
	_sfx_toggle.toggled.connect(_on_sfx_toggled)

func open() -> void:
	_load_settings()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()

func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	var music_enabled := true
	var sfx_enabled := true
	if err == OK:
		music_enabled = bool(config.get_value(SECTION_AUDIO, KEY_MUSIC, true))
		sfx_enabled = bool(config.get_value(SECTION_AUDIO, KEY_SFX, true))
	_music_toggle.button_pressed = music_enabled
	_sfx_toggle.button_pressed = sfx_enabled

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, KEY_MUSIC, _music_toggle.button_pressed)
	config.set_value(SECTION_AUDIO, KEY_SFX, _sfx_toggle.button_pressed)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Save settings failed: %d" % err)

func _on_music_toggled(_pressed: bool) -> void:
	_save_settings()

func _on_sfx_toggled(_pressed: bool) -> void:
	_save_settings()

func _on_close_pressed() -> void:
	close_panel()

func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _panel.get_global_rect().has_point(event.global_position):
			close_panel()
			accept_event()
