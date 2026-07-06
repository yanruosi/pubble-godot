extends Control
class_name ScenePanController

signal pan_changed(pan_x: float, scene_size: Vector2)

## 横向平移控制器：高度铺满 + 水平 1:1 拖动 + 惯性 + 边缘轻微回弹
##
## 节点结构：本节点（SceneViewport，开启 clip_contents）下挂 SceneWorld；
## SceneWorld 的 size 在 _resize 时按 art_base × scale 计算，
## position.x = -pan_x 由本控制器每帧维护。

const FRICTION_PER_FRAME := 0.92
const VELOCITY_LOW_PASS := 0.6
const OVERSCROLL_MAX := 40.0
const BOUNCE_BACK_TIME := 0.18
const MIN_FLING_VELOCITY := 30.0
const TAP_MOVE_THRESHOLD := 6.0

@export var art_base_width: float = 1280.0
@export var art_base_height: float = 720.0

var _scene_world: Control
var _scene_scale: float = 1.0
var _scene_width: float = 0.0
var _view_width: float = 0.0

var _pan_x: float = 0.0
## 进关默认横移：initial_pan_ratio 0=贴左 0.5=居中 1=贴右。
## initial_pan_x>=0：设计稿上该 X 对准屏幕水平中心（如中心线量得 598 就填 598）。
var _initial_pan_ratio: float = 0.5
var _initial_pan_x_design: float = -1.0
var _use_initial_pan_x: bool = false
var _velocity: float = 0.0
var _dragging: bool = false
var _drag_start_pan: float = 0.0
var _drag_start_local: Vector2 = Vector2.ZERO
var _drag_total_dx: float = 0.0
var _drag_total_dy: float = 0.0
var _pan_locked: bool = false
var _bounce_tween: Tween = null
var _tracking_pointer := false
var _pan_gesture_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_on_resized)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_scene_world = get_node_or_null("SceneWorld") as Control
	_recalc_layout(true)

func set_art_base(width: float, height: float) -> void:
	art_base_width = maxf(1.0, width)
	art_base_height = maxf(1.0, height)
	_recalc_layout(true)

func set_initial_pan(ratio: float = 0.5, pan_x_design: float = -1.0, use_pan_x_design: bool = false) -> void:
	_initial_pan_ratio = clampf(ratio, 0.0, 1.0)
	_initial_pan_x_design = pan_x_design
	_use_initial_pan_x = use_pan_x_design

func reset_pan_to_center() -> void:
	_pan_x = _resolve_initial_pan_x()
	_velocity = 0.0
	_apply_world_position()

func _resolve_initial_pan_x() -> float:
	var max_pan: float = max(0.0, _scene_width - _view_width)
	if _use_initial_pan_x:
		# 设计稿像素 X 落在屏幕水平中心：pan = X*scale - 视口宽/2
		var target: float = _initial_pan_x_design * _scene_scale - _view_width * 0.5
		return clampf(target, 0.0, max_pan)
	return max_pan * _initial_pan_ratio

func set_pan_locked(locked: bool) -> void:
	_pan_locked = locked
	if locked:
		_dragging = false
		_tracking_pointer = false
		_pan_gesture_active = false
		_velocity = 0.0
		if _bounce_tween != null and _bounce_tween.is_valid():
			_bounce_tween.kill()

func get_scene_world() -> Control:
	return _scene_world

func get_scene_scale() -> float:
	return _scene_scale

func get_pan_x() -> float:
	return _pan_x

func get_scene_size() -> Vector2:
	if _scene_world == null:
		return Vector2.ZERO
	return _scene_world.size

func _on_viewport_size_changed() -> void:
	_recalc_layout(false)

func _on_resized() -> void:
	_recalc_layout(false)

func _recalc_layout(reset_center: bool) -> void:
	if _scene_world == null:
		_scene_world = get_node_or_null("SceneWorld") as Control
		if _scene_world == null:
			return
	var view_size: Vector2 = size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		view_size = get_viewport_rect().size
	_view_width = max(1.0, view_size.x)
	_scene_scale = view_size.y / max(1.0, art_base_height)
	_scene_width = art_base_width * _scene_scale
	_scene_world.position = Vector2(-_pan_x, 0.0)
	_scene_world.size = Vector2(_scene_width, view_size.y)
	if reset_center:
		reset_pan_to_center()
	else:
		_pan_x = _clamp_pan(_pan_x, false)
		_apply_world_position()

func _process(delta: float) -> void:
	if _scene_world == null:
		return
	if _pan_locked:
		return
	if _dragging:
		return
	if absf(_velocity) > MIN_FLING_VELOCITY:
		_pan_x += _velocity * delta
		_velocity *= FRICTION_PER_FRAME
		var max_pan: float = max(0.0, _scene_width - _view_width)
		if _pan_x < -OVERSCROLL_MAX or _pan_x > max_pan + OVERSCROLL_MAX:
			_velocity = 0.0
			_start_bounce_back()
			return
		if _pan_x < 0.0 or _pan_x > max_pan:
			_velocity = 0.0
			_start_bounce_back()
			return
		_apply_world_position()
	else:
		if _velocity != 0.0:
			_velocity = 0.0
		if _needs_bounce_back():
			_start_bounce_back()

func _input(event: InputEvent) -> void:
	if _pan_locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if not _global_point_in_view(mb.position):
				return
			_tracking_pointer = true
			_pan_gesture_active = false
			_begin_drag(_global_to_local_point(mb.position))
		else:
			if not _tracking_pointer:
				return
			var was_pan_gesture := _pan_gesture_active
			_end_drag()
			_tracking_pointer = false
			_pan_gesture_active = false
			if was_pan_gesture:
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _tracking_pointer and _dragging:
		var mm := event as InputEventMouseMotion
		_apply_drag_motion(_global_to_local_point(mm.position), mm.relative.x)
		if _pan_gesture_active:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not _global_point_in_view(st.position):
				return
			_tracking_pointer = true
			_pan_gesture_active = false
			_begin_drag(_global_to_local_point(st.position))
		else:
			if not _tracking_pointer:
				return
			var was_touch_pan := _pan_gesture_active
			_end_drag()
			_tracking_pointer = false
			_pan_gesture_active = false
			if was_touch_pan:
				get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenDrag and _tracking_pointer and _dragging:
		var sd := event as InputEventScreenDrag
		_apply_drag_motion(_global_to_local_point(sd.position), sd.relative.x)
		if _pan_gesture_active:
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if _tracking_pointer:
		return
	if _pan_locked:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_begin_drag(mb.position)
		else:
			_end_drag()
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_begin_drag(st.position)
		else:
			_end_drag()
		return
	if event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_apply_drag_motion(mm.position, mm.relative.x)
		if _pan_gesture_active:
			accept_event()
		return
	if event is InputEventScreenDrag and _dragging:
		var sd := event as InputEventScreenDrag
		_apply_drag_motion(sd.position, sd.relative.x)
		if _pan_gesture_active:
			accept_event()

func _begin_drag(local_pos: Vector2) -> void:
	_dragging = true
	_drag_start_pan = _pan_x
	_drag_start_local = local_pos
	_drag_total_dx = 0.0
	_drag_total_dy = 0.0
	_velocity = 0.0
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

func _end_drag() -> void:
	if not _dragging:
		return
	_dragging = false
	if absf(_drag_total_dx) < TAP_MOVE_THRESHOLD:
		# 仅点击：吃掉漂移、按需要回弹
		_velocity = 0.0
		if _needs_bounce_back():
			_start_bounce_back()
		return
	if _needs_bounce_back():
		_velocity = 0.0
		_start_bounce_back()

func _apply_drag_delta(total_dx: float, relative_dx: float) -> void:
	_drag_total_dx = total_dx
	var new_pan: float = _drag_start_pan - total_dx
	_pan_x = _clamp_pan(new_pan, true)
	# 低通后的速度（像素 / 秒），用 relative.x 近似估计
	var instant: float = -relative_dx * 60.0
	_velocity = lerp(_velocity, instant, VELOCITY_LOW_PASS)
	_apply_world_position()

func _apply_drag_motion(local_pos: Vector2, relative_dx: float) -> void:
	_drag_total_dx = local_pos.x - _drag_start_local.x
	_drag_total_dy = local_pos.y - _drag_start_local.y
	if absf(_drag_total_dx) >= TAP_MOVE_THRESHOLD and absf(_drag_total_dx) >= absf(_drag_total_dy):
		_pan_gesture_active = true
	if not _pan_gesture_active:
		return
	_apply_drag_delta(_drag_total_dx, relative_dx)

func _global_point_in_view(global_pos: Vector2) -> bool:
	return get_global_rect().has_point(global_pos)

func _global_to_local_point(global_pos: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_pos

func _clamp_pan(value: float, allow_overscroll: bool) -> float:
	var max_pan: float = max(0.0, _scene_width - _view_width)
	if allow_overscroll:
		return clampf(value, -OVERSCROLL_MAX, max_pan + OVERSCROLL_MAX)
	return clampf(value, 0.0, max_pan)

func _needs_bounce_back() -> bool:
	var max_pan: float = max(0.0, _scene_width - _view_width)
	return _pan_x < 0.0 or _pan_x > max_pan

func _start_bounce_back() -> void:
	var max_pan: float = max(0.0, _scene_width - _view_width)
	var target: float = clampf(_pan_x, 0.0, max_pan)
	if is_equal_approx(target, _pan_x):
		return
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_CUBIC)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_method(_set_pan_x_internal, _pan_x, target, BOUNCE_BACK_TIME)

func _set_pan_x_internal(value: float) -> void:
	_pan_x = value
	_apply_world_position()

func _apply_world_position() -> void:
	if _scene_world == null:
		return
	_scene_world.position = Vector2(-roundf(_pan_x), 0.0)
	pan_changed.emit(_pan_x, _scene_world.size)

