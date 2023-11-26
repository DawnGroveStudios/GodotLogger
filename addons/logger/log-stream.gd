@tool
extends Node
##Class that handles all the logging in the addon, methods can either be accessed through
##the "GodotLogger" singelton, or you can instance this class yourself(no need to add it to the tree)

class_name LogStream

#Settings

##Controls how the message should be formatted, follows String.format(), valid keys are: "level", "time", "log_name", "message"
const LOG_MESSAGE_FORMAT = "{log_name}/{level} [lb]{hour}:{minute}:{second}[rb] {message}"


##Whether to use the UTC time or the user
const USE_UTC_TIME_FORMAT = false
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
static var initialized = false

##Emits this signal whenever a message is recieved.
signal log_message(level:LogLevel,message:String)

func _init(log_name:String, min_log_level:=LogLevel.DEFAULT, crash_behavior:=DEFAULT_CRASH_BEHAVIOR):
	_log_name = log_name
	current_log_level = min_log_level
	_crash_behavior = crash_behavior

##prints a message to the log at the debug level.
func debug(message, values={}):
	call_thread_safe("_internal_log", message, values, LogLevel.DEBUG)

##prints a message to the log at the info level.
func info(message:String,values={}):
	call_thread_safe("_internal_log", message, values)

##prints a message to the log at the warning level.
func warn(message:String,values={}):
	call_thread_safe("_internal_log", message, values, LogLevel.WARN)

##Prints a message to the log at the error level.
func error(message:String,values={}):
	call_thread_safe("_internal_log", message, values, LogLevel.ERROR)

##Prints a message to the log at the fatal level, exits the application 
##since there has been a fatal error.
func fatal(message:String,values={}):
	call_thread_safe("_internal_log", message, values, LogLevel.FATAL)

##Shorthand for debug
func dbg(message:String,values={}):
	call_thread_safe("_internal_log", message, values, LogLevel.DEBUG)

##Shorthand for error
func err(message:String,values={}):
	call_thread_safe("_internal_log", message, values, LogLevel.ERROR)

##Throws an error if err_code is not of value "OK" and appends the error code string.
func err_cond_not_ok(err_code:Error, message:String, fatal:=true, other_values_to_be_printed={}):
	if err_code != OK:
		call_thread_safe("_internal_log", message + "" if message.ends_with(".") else "." + " Error string: " + error_string(err_code), other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Throws an error if the "statement" passed is false. Handy for making code "free" from if statements.
func err_cond_false(statement:bool, message:String, fatal:=true, other_values_to_be_printed={}):
	if !statement:
		call_thread_safe("_internal_log", message, other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Throws an error if argument == null
func err_cond_null(arg, message:String, fatal:=true, other_values_to_be_printed={}):
	if arg == null:
		call_thread_safe("_internal_log", message, other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Throws an error if the arg1 isn't equal to arg2. Handy for making code "free" from if statements.
func err_cond_not_equal(arg1, arg2, message:String, fatal:=true, other_values_to_be_printed={}):
	#the type Color is weird in godot, so therefore this edgecase...
	if (arg1 is Color && arg2 is Color && !arg1.is_equal_approx(arg2)) || arg1 != arg2:
		call_thread_safe("_internal_log", str(arg1) + " != " + str(arg2) + ", not allowed. " + message, other_values_to_be_printed, LogLevel.FATAL if fatal else LogLevel.ERROR)

##Main internal logging method, please use the logger() instead since this is not thread safe.
func _internal_log(message:String, values, log_level := LogLevel.INFO):
	if current_log_level > log_level :
		return
	
	var now = Time.get_datetime_dict_from_system(USE_UTC_TIME_FORMAT)
	
	var format_data := {
			"log_name":_log_name,
			"message":message,
			"level":LogLevel.keys()[log_level]
		}
	format_data.merge(now)
	var msg = String(LOG_MESSAGE_FORMAT).format(format_data)
	var stack = get_stack()
	
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
	
	emit_signal("log_message", log_level, msg)
	match log_level:
		LogLevel.DEBUG:
			print_rich("[color=gray]"+msg+"[/color]")
		LogLevel.INFO:
			print_rich(msg)
		LogLevel.WARN:
			if !stack.is_empty():#Aka is connected to debug server -> print to the editor console in addition to pushing the warning.
				print_rich("[color=yellow]"+msg+"[/color]")
			
			push_warning(msg)
			print(_get_reduced_stack(stack) + "\n")
		LogLevel.DEFAULT:
			err("Can't log at 'default' level, this level is only used as filter")
		_:
			msg = msg.replace("[lb]", "[").replace("[rb]", "]")
			push_error(msg)
			if !stack.is_empty():#Aka is connected to debug server -> print to the editor console in addition to pushing the warning.
				printerr(msg)
				#Mimic the native godot behavior of halting execution upon error. 
				if BREAK_ON_ERROR:
					##Please go a few steps down the stack to find the errorous code, since you are currently inside the error handler.
					breakpoint
			print(_get_reduced_stack(stack))
			print("tree: ")
			print_tree()
			print("")#Print empty line to space stack from new message
			if log_level == LogLevel.FATAL:
				_crash_behavior.call()


func _get_reduced_stack(stack:Array)->String:
	var stack_trace_message:=""
	
	if !stack.is_empty():#aka has stack trace.
		stack_trace_message += "at:\n"
		
		for i in range(stack.size()-2):
			var entry = stack[stack.size()-1-i]
			stack_trace_message += "\t" + entry["source"] + ":" + str(entry["line"]) + " in func " + entry["function"] + "\n"
	else:
		##TODO: test print_debug()
		stack_trace_message = "No stack trace available, please run from within the editor or connect to a remote debug context."
	return stack_trace_message

##Internal method.
func _set_level(level:LogLevel):
	level = _get_external_log_level() if level == LogLevel.DEFAULT else level
	info("setting log level to " + LogLevel.keys()[level])
	current_log_level = level

##Internal method.
func _get_external_log_level()->LogLevel:
	var key = Config.get_var("log-level","info").to_upper()
	if LogLevel.keys().has(key):
		return LogLevel[key]
	else:
		warn("The variable log-level is set to an illegal type, defaulting to info")
		return LogLevel.INFO
