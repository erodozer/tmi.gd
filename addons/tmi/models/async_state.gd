extends RefCounted
class_name TmiAsyncState

## flags to indicate that the profile isn't done loading
## used by any async APIs that extend the object
var _loading: Dictionary = {}

## async APIs may add their own lifetimes to an async state.
## This is used to refruse calling the APIs excessively for data that does not frequently change.
var cache_expirations: Dictionary = {}

signal loaded

func is_loading():
	return len(_loading) > 0
	
func is_cached(name: String):
	return Time.get_unix_time_from_system() < cache_expirations.get(name, -1)
	
func cache(name: String, duration: int):
	cache_expirations[name] = Time.get_unix_time_from_system() + duration

func push_loading(name: String):
	_loading[name] = true

func pop_loading(name: String):
	_loading.erase(name)

	if not is_loading():
		loaded.emit()

func wait_for(name: String, fn: Callable):
	push_loading(name)
	await fn.call()
	pop_loading(name)
