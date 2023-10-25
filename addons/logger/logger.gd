@tool
extends LogStream

##A default instance of the LogStream. Instanced as the main log singelton.

class_name Log


func _init():
	super("Main", LogLevel.DEFAULT)
