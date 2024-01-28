extends RefCounted
class_name TmiAsyncState

# flags to indicate that the profile isn't done loading
# used by any async APIs that extend the object
var _loading: Dictionary = {}

signal loaded

var is_loading:
	get = _is_loading

func _is_loading():
	return len(_loading) > 0

func push_loading(name):
	_loading[name] = true

func pop_loading(name):
	_loading.erase(name)

	if not _is_loading():
		loaded.emit()

func wait_for(name, fn: Callable):
	push_loading(name)
	await fn.call()
	pop_loading(name)
