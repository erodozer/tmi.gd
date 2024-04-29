extends RefCounted

enum LogLevel {
	NONE,
	ERROR,
	WARN,
	INFO,
	DEBUG
}

var allowed_level: LogLevel = LogLevel.INFO
var scope: String = ""

func _init(module):
	scope = module
	var allowed_level = ProjectSettings.get_setting_with_override("application/tmi/log_level")
	if allowed_level:
		match allowed_level.to_lower():
			"warn":
				self.allowed_level = LogLevel.WARN
			"debug":
				self.allowed_level = LogLevel.DEBUG
			"info":
				self.allowed_level = LogLevel.INFO
			"error":
				self.allowed_level = LogLevel.ERROR
			_:
				self.allowed_level = LogLevel.INFO
			
func fmt_msg(msg: String, level: String):
	return "[tmi/%s][%s]: %s" % [scope, level, msg]
	
func info(msg: String):
	var text = fmt_msg(msg, "INFO")
	match allowed_level:
		LogLevel.DEBUG, LogLevel.INFO:
			print(text)
			
func debug(msg: String):
	var text = fmt_msg(msg, "DEBUG")
	match allowed_level:
		LogLevel.DEBUG:
			print(text)

func warn(msg: String):
	var text = fmt_msg(msg, "WARN")
	match allowed_level:
		LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN:
			push_warning(text)
			
func error(msg: String):
	var text = fmt_msg(msg, "ERROR")
	match allowed_level:
		LogLevel.DEBUG, LogLevel.WARN, LogLevel.INFO, LogLevel.ERROR:
			push_error(msg)
