extends Node
class_name TutorialController

const STEPS := [
	"打开嫂子站 Tab",
	"点击曝光",
	"收取情报点",
	"打开艺人 Tab",
	"通关帖子关1",
	"商城买专辑",
	"升级会员",
	"签售活动",
	"签售成功",
	"教程完成",
]

var _save_manager: SaveManager
var _overlay: CanvasLayer
var _hint_label: Label


func _ready() -> void:
	_save_manager = get_node_or_null("/root/SaveManagerSingleton") as SaveManager
	_build_overlay()


func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = 450
	_overlay.visible = false
	add_child(_overlay)

	var panel := PanelContainer.new()
	panel.position = Vector2(280, 620)
	panel.custom_minimum_size = Vector2(720, 80)
	_overlay.add_child(panel)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_hint_label)


func is_active() -> bool:
	if _save_manager == null:
		return false
	return not _save_manager.tutorialdone


func get_step() -> int:
	if _save_manager == null:
		return 0
	return _save_manager.tutorialstep


func advance_step() -> void:
	if _save_manager == null:
		return
	if _save_manager.tutorialdone:
		return
	_save_manager.tutorialstep += 1
	if _save_manager.tutorialstep >= STEPS.size():
		_save_manager.tutorialdone = true
		_save_manager.tutorialstep = STEPS.size()
	_overlay_update()
	_save_manager.save_progress()


func show_hint_for_step(step: int) -> void:
	if _save_manager == null or _save_manager.tutorialdone:
		_overlay.visible = false
		return
	if step < 0 or step >= STEPS.size():
		_overlay.visible = false
		return
	_hint_label.text = "教程 %d/%d：%s" % [step + 1, STEPS.size(), STEPS[step]]
	_overlay.visible = true


func _overlay_update() -> void:
	show_hint_for_step(get_step())


func notify_tab_opened(tab_name: String) -> void:
	if not is_active():
		return
	match get_step():
		0:
			if tab_name == "sister":
				advance_step()
		3:
			if tab_name == "artist":
				advance_step()


func notify_instance_collected() -> void:
	if is_active() and get_step() == 2:
		advance_step()


func notify_level_cleared() -> void:
	if is_active() and get_step() == 4:
		advance_step()


func notify_shop_purchased() -> void:
	if is_active() and get_step() == 5:
		advance_step()


func notify_fan_upgraded() -> void:
	if is_active() and get_step() == 6:
		advance_step()


func notify_sign_done() -> void:
	if is_active() and get_step() in [7, 8]:
		advance_step()
		if get_step() >= 9:
			advance_step()
