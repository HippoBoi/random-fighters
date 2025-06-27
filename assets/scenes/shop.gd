extends Control

signal closeShop(shop);

var character: CharacterBody3D = null;
var selectedItem = null;

func _ready() -> void:
	_setupShop();

func _setupShop():
	var itemsContainer = $Shop/ItemsContainer;
	var itemTemplate = itemsContainer.get_node("itemTemplate");
	var itemsIndex = 0;
	
	for item in Constants.items:
		var newItem: Button = itemTemplate.duplicate();
		var itemPrice: RichTextLabel = newItem.get_node("Price");
		var itemTexture: TextureRect = newItem.get_node("TextureRect");
		
		if (itemsIndex > 2):
			itemsContainer = $Shop/ItemsContainer2;
		
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
		
		itemsIndex += 1;

func _on_close_shop() -> void:
	closeShop.emit(self);

func _toggle_shop():
	visible = not visible;

func _on_buy_pressed() -> void:
	if not (selectedItem):
		return;
	
	var playerTokens = character.tokens;
	var itemPrice = int(selectedItem.get_node("Price").text);
	if (playerTokens - itemPrice >= 0):
		onItemBought(character)

func onItemBought(character: CharacterBody3D):
	if not (selectedItem):
		return;
	
	var itemWithStats = null;
	for item in Constants.items:
		if (item.name ==  selectedItem.name):
			itemWithStats = item;
	
	character.tokens -= int(selectedItem.get_node("Price").text);
	character.rpc("onItemPurchase", itemWithStats);
	selectedItem = null;
	
	var newSound = AudioStreamPlayer.new();
	add_child(newSound);
	
	newSound.stream = preload("res://assets/sounds/shop/item_bought.ogg");
	newSound.pitch_scale = randf();
	newSound.pitch_scale = clamp(newSound.pitch_scale, 0.75, 1.25);
	newSound.play();
	newSound.finished.connect(func():
		newSound.queue_free();
	);
