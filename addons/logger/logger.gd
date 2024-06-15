@tool
class_name Log
extends Node

signal log_message(level:LogLevel,message:String)

enum LogLevel {
	DEBUG,
	INFO,
	WARN,
	ERROR,
	FATAL,
}

const COLORS = {
	"debug" : "#BEFFE7",
	"info"  : "white",
	"warn"  : "yellow",
	"error" : "red",
}

const LOG_FORMAT = "{level} [{time}]{prefix} {message} "


var CURRENT_LOG_LEVEL=LogLevel.DEBUG
var USE_ISOTIME: bool = false
var write_logs: bool = true
var printing_stack: bool = false
var log_path: String = "res://.logs/game.log"
var _config

var _prefix  = ""
var _default_args = {}

var _file: FileAccess


func _ready():
	_set_loglevel(Config.get_var("log-level","debug"))
	_set_time_format(Config.get_var("use-isotime", "false"))


func _set_loglevel(level:String):
	logger("setting log level",{"level":level},LogLevel.INFO)
	match level.to_lower():
		"debug":
			CURRENT_LOG_LEVEL = LogLevel.DEBUG
		"info":
			CURRENT_LOG_LEVEL = LogLevel.INFO
		"warn":
			CURRENT_LOG_LEVEL = LogLevel.WARN
		"error":
			CURRENT_LOG_LEVEL = LogLevel.ERROR
		"fatal":
			CURRENT_LOG_LEVEL = LogLevel.FATAL


func _set_time_format(level:String):
	logger("setting iso format",{"level":level},LogLevel.INFO)
	match level.to_lower():
		"true":
			USE_ISOTIME = true
		"false": 
			USE_ISOTIME = false


func with(prefix:String="",args:Dictionary={}) ->Log :
	var l = Log.new()
	l.CURRENT_LOG_LEVEL = self.CURRENT_LOG_LEVEL
	l._prefix = " %s |" % prefix
	for k in args:
		l._default_args[k] = args[k]
	return l


func logger(message:String,values,log_level=LogLevel.INFO):
	if CURRENT_LOG_LEVEL > log_level :
		return
	
	var msg := _get_format_massage(message, log_level)
	msg = _add_values(msg, values)
	
	if OS.get_main_thread_id() != OS.get_thread_caller_id() and log_level == LogLevel.DEBUG:
		print_rich("[%d]Cannot retrieve debug info outside the main thread:\n\t%s" % [OS.get_thread_caller_id(),msg])
		return
	
	emit_signal("log_message", log_level, msg)
	_write_logs(msg)
	#call_thread_safe("_write_logs", msg)
	_print_msg(log_level, msg)


func _get_format_massage(message: String, log_level) -> String:
	var msg = LOG_FORMAT.format(
		{
			"prefix":_prefix,
			"message":message,
			"time": _get_time(),
			"level": LogLevel.keys()[log_level].rpad(5, " ")
		})
	return msg


func _get_time():
	var now = Time.get_datetime_dict_from_system(true)
	if USE_ISOTIME:
		return Time.get_datetime_string_from_datetime_dict(now, false)
	
	now.day = "%02d" % now.day
	now.month = "%02d" % now.month
	now.hour = "%02d" % now.hour
	now.minute = "%02d" % now.minute
	now.second = "%02d" % now.second
	return "{day}/{month}/{year} {hour}:{minute}:{second}".format(now)


func _add_values(msg, values):
	match typeof(values):
		TYPE_ARRAY:
			if values.size() > 0:
				msg += "["
				for k in values:
					msg += "{k},".format({"k":JSON.stringify(k)})
				msg = msg.left(msg.length()-1)+"]"
		TYPE_DICTIONARY:
			for k in _default_args:
				values[k] = _default_args[k]
			if values.size() > 0:
				msg += "{"
				for k in values:
					if typeof(values[k]) == TYPE_OBJECT && values[k] != null:
						msg += '"{k}":{v},'.format({"k":k,"v":JSON.stringify(JsonData.to_dict(values[k],false))})
					else:
						msg += '"{k}":{v},'.format({"k":k,"v":JSON.stringify(values[k])})
				msg = msg.left(msg.length()-1)+"}"
		TYPE_PACKED_BYTE_ARRAY:
			if values == null:
				msg += JSON.stringify(null)
			else:
				msg += JSON.stringify(JsonData.unmarshal_bytes_to_dict(values))
		TYPE_OBJECT:
			if values == null:
				msg += JSON.stringify(null)
			else:
				msg += JSON.stringify(JsonData.to_dict(values,false))
		TYPE_NIL:
			msg += JSON.stringify(null)
		_:
			msg += JSON.stringify(values)
	return msg


func _print_msg(log_level, msg: String):
	match log_level:
		LogLevel.DEBUG:
			print_rich("[color={debug}]%s[/color]".format(COLORS) % [msg])
			if printing_stack: print_stack()
		
		LogLevel.INFO:
			print_rich("[color={info}]%s[/color]".format(COLORS) % [msg])
		
		LogLevel.WARN:
			print_rich("[color={warn}]%s[/color]".format(COLORS) % [msg])
			push_warning(msg)
			print_stack()
		
		LogLevel.ERROR:
			push_error(msg)
			print_rich("[color={error}]%s[/color]".format(COLORS) % [msg])
			print_stack()
			print_tree()
		
		LogLevel.FATAL:
			push_error(msg)
			printerr(msg)
			print_stack()
			print_tree()
			get_tree().quit()
		
		_:
			print_rich(msg)


func debug(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.DEBUG)


func info(message:String,values={}):
	call_thread_safe("logger",message,values)


func warn(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.WARN)


func error(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.ERROR)


func fatal(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.FATAL)


func _write_logs(message:String):
	if !write_logs:
		return
	
	if not _file:
		var global_logger = _get_global_logger()
		if not global_logger: return
		if not global_logger._file:
			global_logger._load_file()
		_file = global_logger._file
	
	_file.store_line(message)
	_file.flush()


func _get_log_path():
	if Engine.is_editor_hint(): 
		var path_array = log_path.split(".")
		return  "%s_editor.%s" % [path_array[0], path_array[1]]
	return log_path


func _get_global_logger():
	if not Engine.has_singleton("GodotLogger"): 
		Engine.register_singleton("GodotLogger", Log.new())
	return Engine.get_singleton("GodotLogger")


func _load_file():
	_file = FileAccess.open(_get_log_path(), FileAccess.WRITE)
