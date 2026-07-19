extends RefCounted

var _ctx


func _init(ctx) -> void:
	_ctx = ctx


func roll_hot(item: Dictionary) -> void:
	_ctx.heat.roll_hot(item)
