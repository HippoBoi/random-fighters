extends Control

@onready var bgModeName = $loopingStatus;
var bgNamesCreated = [];
var bgNamesTimer = 0;

var playerId;

signal returnToLobby;

func _process(delta: float) -> void:
	_animate_bg_mode_name(delta);

func _animate_bg_mode_name(_delta):
	bgNamesTimer += _delta;
	var decimalTimer = int(round(bgNamesTimer * 100));
	if (not (decimalTimer % 4 == 0) or bgNamesCreated.size() > 12):
		return;
	
	var duration = randi_range(6, 16);
	var yPos = randi_range(-170, 220);
	var newName: RichTextLabel = bgModeName.duplicate();
	var tween = get_tree().create_tween();
	tween.tween_property(newName, "global_position", Vector2(-400, yPos), duration);
	tween.finished.connect(func(): 
		var pos = bgNamesCreated.find(newName);
		bgNamesCreated.remove_at(pos);
		newName.queue_free();
	);
	
	newName.global_position.y = yPos;
	newName.visible = true;
	add_child(newName);
	
	bgNamesCreated.append(newName);

func _on_return_pressed() -> void:
	returnToLobby.emit();
