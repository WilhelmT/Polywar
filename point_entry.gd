class_name PointEntry
extends RefCounted

var index: int
var significance: float
var prev_index: int
var next_index: int

func _init(idx: int, sig: float, prev: int, next: int) -> void:
	index = idx
	significance = sig
	prev_index = prev
	next_index = next
