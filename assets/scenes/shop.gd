extends Control

signal closeShop(shop);
signal onItemPurchase(item, playerId);

var character: CharacterBody3D = null;
var selectedItem = null;

func _ready() -> void:
	_setupShop();

func _setupShop():
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

func _on_close_shop() -> void:
	closeShop.emit(self);

func _toggle_shop():
	visible = not visible;

func _on_buy_pressed() -> void:
	print(character);
	# TODO: check player's money and validate item buy, then emit function to grant stats
	
	# onItemPurchase.emit(selectedItem, playerId);
	selectedItem = null;

func onItemBought(item: Button, character: CharacterBody3D):
	if not (item):
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
