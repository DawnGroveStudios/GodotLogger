# GodotLogger
JSON-formatted logger

# Settings

```
var CURRENT_LOG_LEVEL=LogLevel.INFO
var write_logs:bool = false
var log_path:String = "res://game.log"
```

# Singletons
`GodotLogger`
- `GodotLogger.debug(msg,data)`
- `GodotLogger.info(msg,data)`
- `GodotLogger.warn(msg,data)`
- `GodotLogger.error(msg,data)`
- `GodotLogger.fatal(msg,data)`

# Classes
## Log
Is the class implementation of the singleton logger. The `CURRENT_LOG_LEVEL` can be set to any of the following levels:
```
enum LogLevel {
	DEBUG,
	INFO,
	WARN,
	ERROR,
	FATAL,
}
```
When it is set anything less than the current log level will be filtered out


## JsonData
### Methods
- marshal(obj:Object,compact:bool=false,compressMode:int=-1,skip_whitelist:bool=false) -> PackedByteArray:

- unmarshal(dict:Dictionary,obj:Object,compressMode:int=-1) -> bool:

- unmarshal_bytes_to_dict(data:PackedByteArray,compressMode:int=-1) -> Dictionary:

- unmarshal_bytes(data:PackedByteArray,obj:Object,compressMode:int=-1) -> bool:

- to_dict(obj:Object,compact:bool,skip_whitelist:bool=false) ->Dictionary:

## Config
Will get either flags or env vars for the program and return the value or the default value.
### Methods

- get_var(name,default=""):

- get_int(name,default=0) -> int:
	
- get_bool(name,default=false,prefix:String="") -> bool:

- get_custom_var(name,type,default=null):
