class_name Constants

enum CursorTypes {
	cursor,
	cursorAttack
}

enum GameModes {
	Free_For_All,
	Foggy_Vision,
	Hippo_Capture,
	Doom_Bot,
	Snowmen,
	Arena,
	Trainwreck
}

const items = [
	{
		"name": "Cool Bow",
		"price": 15,
		"stats": {
			"dmg": 2,
			"attackSpeed": 2,
		},
		"texture": "res://assets/textures/items/broken_bow.png"
	},
	{
		"name": "Heaven Sword",
		"price": 15,
		"stats": {
			"dmg": 4,
		},
		"texture": "res://assets/textures/items/heaven_sword.png"
	},
	{
		"name": "Epic Rod",
		"price": 15,
		"stats": {
			"dmg": 2,
			"cooldownReduction": 1.25,
		},
		"texture": "res://assets/textures/items/rod.png"
	},
	{
		"name": "Heaven Shield",
		"price": 15,
		"stats": {
			"hp": 20,
			"armor": 15
		},
		"texture": "res://assets/textures/items/heaven_shield.png"
	},
	{
		"name": "Life Shield",
		"price": 15,
		"stats": {
			"hp": 50
		},
		"texture": "res://assets/textures/items/life_shield.png"
	},
	{
		"name": "Speed Boots",
		"price": 15,
		"stats": {
			"speed": 1,
		},
		"texture": "res://assets/textures/items/boots.png"
	},
	{
		"name": "Sword Shield",
		"price": 25,
		"stats": {
			"dmg": 6,
			"armor": 15,
		},
		"texture": "res://assets/textures/items/sword_shield.png"
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
