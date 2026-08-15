class_name Constants

static var DEBUG = false;

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
	Trainwreck,
	Heaven,
	Seaweeds
}

enum MatchTypes {
	Versus,
	Story,
	Training
}

const ModeDescriptions = {
	"Multiplayer": "Join or create a multiplayer a lobby to play team matches with people around the world.",
	"Story": "Play the singleplayer story mode of Random Fighters. Fight against multiple rounds of enemies and bosses",
	"Training": "Play every character or try to learn combos in this sandbox environment."
}

const items = [
	{
		"name": "Cool Bow",
		"price": 15,
		"stats": {
			"dmg": 2.5,
			"attackSpeed": 2.5
		},
		"texture": "res://assets/textures/items/broken_bow.png"
	},
	{
		"name": "Heaven Sword",
		"price": 15,
		"stats": {
			"dmg": 5
		},
		"texture": "res://assets/textures/items/heaven_sword.png"
	},
	{
		"name": "Epic Rod",
		"price": 15,
		"stats": {
			"dmg": 2,
			"cooldownReduction": 3
		},
		"texture": "res://assets/textures/items/rod.png"
	},
	{
		"name": "Heaven Shield",
		"price": 20,
		"stats": {
			"hp": 20,
			"armor": 12
		},
		"texture": "res://assets/textures/items/heaven_shield.png"
	},
	{
		"name": "Life Shield",
		"price": 15,
		"stats": {
			"hp": 40
		},
		"texture": "res://assets/textures/items/life_shield.png"
	},
	{
		"name": "Speed Boots",
		"price": 15,
		"stats": {
			"speed": 3
		},
		"texture": "res://assets/textures/items/boots.png"
	},
	{
		"name": "Sword Shield",
		"price": 30,
		"stats": {
			"dmg": 5,
			"armor": 6
		},
		"texture": "res://assets/textures/items/sword_shield.png"
	},
	{
		"name": "Divino",
		"price": 55,
		"stats": {
			"hp": 45,
			"dmg": 5,
			"attackSpeed": 4,
			"cooldownReduction": 4,
			"speed": 3
		},
		"texture": "res://assets/textures/looping_background.png"
	}
];
