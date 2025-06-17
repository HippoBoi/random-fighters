extends Control

func _ready() -> void:
	var itemsContainer = $Shop/ItemsContainer;
	var itemTemplate = itemsContainer.get_node("itemTemplate");
	
	for item in Constants.items:
		var newItem: Button = itemTemplate.duplicate();
		var itemText: RichTextLabel = newItem.get_node("RichTextLabel");
		var itemTexture: TextureRect = newItem.get_node("TextureRect");
		
		itemText.text = item.name;
		itemTexture.texture = load(item.texture);
		
		itemsContainer.add_child(newItem);
		newItem.visible = true;

func _process(delta: float) -> void:
	if (Input.is_action_just_pressed("shop")):
		_toggle_shop();

func _on_close_shop() -> void:
	_toggle_shop();

func _toggle_shop():
	visible = not visible;
