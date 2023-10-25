@tool
extends Node
##Class that handles all the logging in the addon, methods can either be accessed through
##the "GodotLogger" singelton, or you can instance this class yourself(no need to add it to the tree)

class_name LogStream

#Settings

##Controls how the message should be formatted, follows String.format(), valid keys are: "level", "time", "log_name", "message"
const LOG_MESSAGE_FORMAT = "{log_name}/{level} [{time}] {message}"

##Whether to write logged messages to a file as well as to the console.
const WRITE_LOGS_TO_FILE = false

##Controls how the message time should be recorded in the console, valid keys are the dictionary keys in Time.get_date_time()
const LOG_TIME_FORMAT = "{hour}:{minute}:{second}"
##Controls where the log files should be placed. Valid keys are the dictionary keys in Time.get_date_time()
const LOG_FILE_PATH = "user://logs/{year}{month}{date} - {hour}:{minute}:{second}.log"
##Whether to use the UTS time or the user
const USE_UTS_TIME_FORMAT = false
##Enables a breakpoint to mimic the godot behavior where the application doesn't crash when connected to debug environment, 
##but instead freezed and shows the stack etc in the debug panel.
const BREAK_ON_ERROR = true

##Controls the behavior when a fatal error has been logged. 
##Edit to customize the behavior.
static var DEFAULT_CRASH_BEHAVIOR := func():
	#Restart the process to the main scene. (Uncomment if wanted), 
	#note that we don't want to restart if we crash on init, then we get stuck in an infinite crash-loop, which isn't fun for anyone. 
	#if get_tree().get_frame()>0:
	#	var _ret = OS.create_process(OS.get_executable_path(), OS.get_cmdline_args())
	
	#Choose crash mechanism. Difference is that get_tree().quit() quits at the end of the frame, 
	#enabling multiple fatal errors to be cast, printing multiple stack traces etc. 
	#Warning regarding the use of OS.crash() in the docs can safely be regarded in this case.
	OS.crash("Crash since falal error ocurred")
	#get_tree().quit(-1)

#end of settings

enum LogLevel {
	DEFAULT,
	DEBUG,
	INFO,
	WARN,
	ERROR,
	FATAL,
}

var current_log_level:LogLevel = LogLevel.INFO:set= _set_level
var _log_name:String
var _print_action:Callable
var _crash_behavior

static var _log_file:FileAccess
static var _start_time = Time.get_datetime_string_from_system(USE_UTS_TIME_FORMAT)
static var initialized = false

##Emits this signal whenever a message is recieved.
signal log_message(level:LogLevel,message:String)

func _init(log_name:String, min_log_level:=LogLevel.DEFAULT, crash_behavior:=DEFAULT_CRASH_BEHAVIOR):
	_log_name = log_name
	current_log_level = _get_external_log_level() if min_log_level == LogLevel.DEFAULT else min_log_level
	_crash_behavior = crash_behavior

##prints a message in the log. Defaulting the level to INFO.
func logger(message:String, values={}, log_level := LogLevel.INFO):
	call_thread_safe("_internal_log", message, values, log_level)

##prints a message to the log at the debug level.
func debug(message, values={}):
	logger(message, values, LogLevel.DEBUG)


##prints a message to the log at the info level.
func info(message:String,values={}):
	logger(message,values)

##prints a message to the log at the warning level.
func warn(message:String,values={}):
	logger(message,values,LogLevel.WARN)

##Prints a message to the log at the error level.
func error(message:String,values={}):
	logger(message,values,LogLevel.ERROR)

##Prints a message to the log at the fatal level, exits the application 
##since there has been a fatal error.
func fatal(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.FATAL)

##Shorthand for debug
func dbg(message:String,values={}):
	debug(message, values)

##Shorthand for error
func err(message:String,values={}):
	error(message, values)

##Throws an error if err_code is not of value "OK" and appends the error code string.
func err_cond_not_ok(err_code:Error, message:String, fatal:=true, other_values_to_be_printed={}):
	if err_code != OK:
		logger(message + ". Error code: " + error_string(err_code), other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Throws an error if the "statement" passed is false. Handy for making code "free" from if statements.
func err_cond_false(statement:bool, message:String, fatal:=true, other_values_to_be_printed={}):
	if !statement:
		logger(message, other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Throws an error if argument == null
func err_cond_null(arg, message:String, fatal:=true, other_values_to_be_printed={}):
	if arg == null:
		logger(message, other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Throws an error if the arg1 isn't equal to arg2. Handy for making code "free" from if statements.
func err_cond_not_equal(arg1, arg2, message:String, fatal:=true, other_values_to_be_printed={}):
	#the type Color is weird in godot, so therefore this edgecase...
	if (arg1 is Color && arg2 is Color && !arg1.is_equal_approx(arg2)) || arg1 != arg2:
		logger(str(arg1) + " != " + str(arg2) + ", not allowed. " + message, other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Main internal logging method, please use the logger() instead since this is not thread safe.
func _internal_log(message:String, values, log_level := LogLevel.INFO):
	if current_log_level > log_level :
		return
	
	var now = Time.get_datetime_dict_from_system(USE_UTS_TIME_FORMAT)
	
	var msg = String(LOG_MESSAGE_FORMAT).format(
		{
			"log_name":_log_name,
			"message":message,
			"time":String(LOG_TIME_FORMAT).format(now),
			"level":LogLevel.keys()[log_level]
		})
	
	
	match typeof(values):
		TYPE_ARRAY:
			if values.size() > 0:
				msg += "["
				for k in values:
					msg += "{k},".format({"k":JSON.stringify(k)})
				msg = msg.left(msg.length()-1)+"]"
		TYPE_DICTIONARY:
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
	#This isn't a problem since print_stack() doesn't do anything in stackless instances (AKA without remote debugger or from other threads)
	#As of 4.2 the thread problem will no longer be an issue to my knowledge. 
	
	#if OS.get_main_thread_id() != OS.get_thread_caller_id() and log_level == LogLevel.DEBUG:
	#	print("[%d]Cannot retrieve debug info outside the main thread:\n\t%s" % [OS.get_thread_caller_id(),msg])
	#	return
	
	_write_logs_to_file(msg)
	emit_signal("log_message", log_level, msg)
	match log_level:
		LogLevel.DEBUG:
			print(msg)
			print_stack()
		LogLevel.INFO:
			print(msg)
		LogLevel.WARN:
			if !OS.has_feature("template"):#Aka not running in an exported scenario -> ran from the editor, otherwise the message shows up twice in system console.
				print(msg)
			push_warning(msg)
			print_stack()
		LogLevel.ERROR:
			push_error(msg)
			if !OS.has_feature("template"):#aka not running in an exported scenario -> ran from the editor, otherwise the message shows up twice in system console.
				printerr(msg)
				#mimic the native godot behavior of halting execution upon error. 
				if BREAK_ON_ERROR:
					##Please go a few steps down the stack to find the errorous code, since you are currently inside the error handler.
					breakpoint
			print_stack()
			print_tree()
		LogLevel.FATAL:
			push_error(msg)
			if !OS.has_feature("template"):#aka not running in an exported scenario -> ran from the editor, otherwise the message shows up twice in system console.
				printerr(msg)
				#mimic the native godot behavior of halting execution upon error. 
				if BREAK_ON_ERROR:
					##Please go a few steps down the stack to find the errorous code, since you are currently inside the error handler.
					breakpoint
			print_stack()
			print_tree()
			_crash_behavior.call()
		_:
			print(msg)

##internal method 
static func _write_logs_to_file(message:String):
	if !WRITE_LOGS_TO_FILE:
		return
	if _log_file == null:
		_log_file = FileAccess.open(LOG_FILE_PATH.format(_start_time),FileAccess.WRITE)
	_log_file.store_line(message)


func _set_level(level:LogLevel):
	info("setting log level to " + LogLevel.keys()[level])
	current_log_level = level


func _get_external_log_level()->LogLevel:
	var key = Config.get_var("log-level","info").to_upper()
	if LogLevel.keys().has(key):
		return LogLevel[key]
	else:
		warn("The variable log-level is set to an illegal type, defaulting to info")
		return LogLevel.INFO
