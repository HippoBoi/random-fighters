extends Control

signal onItemPurchase(item)

var selectedItem = null;

func _ready() -> void:
	var itemsContainer = $Shop/ItemsContainer;
	var itemTemplate = itemsContainer.get_node("itemTemplate");
	
	for item in Constants.items:
		var newItem: Button = itemTemplate.duplicate();
		var itemPrice: RichTextLabel = newItem.get_node("RichTextLabel");
		var itemTexture: TextureRect = newItem.get_node("TextureRect");
		
		newItem.name = item.name;
		itemPrice.text = "$" + str(item.price);
		itemTexture.texture = load(item.texture);
		
		newItem.mouse_entered.connect(func():
			var newSound = AudioStreamPlayer.new();
			newItem.add_child(newSound);
			
			newSound.stream = preload("res://assets/sounds/shop/item_hover.ogg");
			newSound.pitch_scale = randf();
			newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.5);
			newSound.play();
			newSound.finished.connect(func():
				newSound.queue_free();
			);
		);
		newItem.button_down.connect(func():
			selectedItem = newItem;
			
			if (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
				_on_buy_pressed();
		);
		
		itemsContainer.add_child(newItem);
		newItem.visible = true;

func _process(_delta: float) -> void:
	if (Input.is_action_just_pressed("shop")):
		_toggle_shop();

func _on_close_shop() -> void:
	_toggle_shop();

func _toggle_shop():
	visible = not visible;

func _on_buy_pressed() -> void:
	if not (selectedItem):
		return;
	
	var newSound = AudioStreamPlayer.new();
	add_child(newSound);
	
	newSound.stream = preload("res://assets/sounds/shop/item_bought.ogg");
	newSound.pitch_scale = randf();
	newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.25);
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);
	
	onItemPurchase.emit(selectedItem);
	selectedItem = null;
