class_name Constants

enum CursorTypes {
	cursor,
	cursorAttack
}

enum GameModes {
	Free_For_All,
	Foggy_Vision,
	Hippo_Capture,
	Doom_Bot
}

const items = [
	{
		"name": "Broken Bow",
		"price": 15,
		"stats": {
			"dmg": 2,
			"attackSpeed": 2,
		},
		"texture": "res://assets/textures/items/broken_bow.png"
	},
	{
		"name": "Heaven Sword",
		"price": 20,
		"stats": {
			"dmg": 4,
		},
		"texture": "res://assets/textures/items/heaven_sword.png"
	},{
		"name": "Heaven Shield",
		"price": 20,
		"stats": {
			"hp": 25,
			"armor": 10
		},
		"texture": "res://assets/textures/items/heaven_shield.png"
	},
	{
		"name": "Epic Rod",
		"price": 25,
		"stats": {
			"dmg": 3,
			"cooldownReduction": 2.0,
		},
		"texture": "res://assets/textures/items/placeholder.png"
	},
	{
		"name": "Divino",
		"price": 45,
		"stats": {
			"hp": 15,
			"dmg": 7,
			"attackSpeed": 2,
			"cooldownReduction": 2,
			"speed": 1
		},
		"texture": "res://assets/textures/looping_background.png"
	}
];
