extends Control

func _ready() -> void:
	var itemTemplate = $Shop/ItemsContainer/itemTemplate;
	
	for i in Constants.items:
		var newItem = itemTemplate.duplicate();
		newItem.name = i.name;
