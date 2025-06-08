extends Node

var cursor = load("res://assets/sprites/cursor.png");
var cursorAttack = load("res://assets/sprites/cursorAttack.png");

var currentIcon: Constants.CursorTypes;

func changeCursor(cursorIcon: Constants.CursorTypes) -> void:
	if (currentIcon == cursorIcon):
		return;
	
	if (cursorIcon == Constants.CursorTypes.cursor):
		Input.set_custom_mouse_cursor(cursor);
	elif (cursorIcon == Constants.CursorTypes.cursorAttack):
		Input.set_custom_mouse_cursor(cursorAttack);
	
	currentIcon = cursorIcon;
