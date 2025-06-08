class_name PlayerData
extends Node

var playerID;
var username;
var character;
var charInstance;
var team;

func _init(_playerID, _username, _character, _charInstance, _team) -> void:
	self.playerID = _playerID;
	self.username = _username;
	self.character = _character;
	self.charInstance = _charInstance;
	self.team = _team;
