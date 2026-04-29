class_name PlayerData
extends Node

var playerID;
var username;
var character;
var charInstance;
var team;

var kills = 0;
var deaths = 0;
var assists = 0;
var items = [];

func _init(_playerID, _username, _character, _charInstance, _team) -> void:
	self.playerID = _playerID;
	self.username = _username;
	self.character = _character;
	self.charInstance = _charInstance;
	self.team = _team;
