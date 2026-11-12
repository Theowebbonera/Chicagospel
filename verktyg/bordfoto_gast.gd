extends Node
## En enkel klient som spelar med testspelarens logik på sin egen vy (ur tests/test_online_scen.gd).
const Klient := preload("res://scripts/klient.gd")
const Robot := preload("res://tests/testspelare.gd")
const Regler := preload("res://scripts/regler.gd")
const Motor := preload("res://scripts/motor.gd")
var k
var plats := -1
var kod := ""
var s := {}
var regler_d := {}
var skickat := false
var rng := RandomNumberGenerator.new()

func _init() -> void:
	k = Klient.new()
	add_child(k)
	k.meddelande.connect(_m)

func _m(d: Dictionary) -> void:
	match d.t:
		"valkommen":
			plats = d.plats
			kod = d.kod
		"lobby":
			regler_d = d.regler
		"steg", "ogonblick":
			s = d.s
			skickat = false
		"fel":
			skickat = false

func _process(_dt: float) -> void:
	if skickat or s.is_empty() or plats < 0 or s.tur != plats:
		return
	var vy: Dictionary = s.egen.duplicate(true)
	var r := Regler.new()
	r.fran_dict(regler_d)
	vy["regler"] = r
	match int(s.fas):
		Motor.Fas.BYTE:
			if int(vy.get("upp_kort", -1)) >= 0:
				k.skicka({"t": "upp", "ja": rng.randf() < 0.5})
			else:
				k.skicka({"t": "byt", "kort": Robot.valj_byte(vy, Robot.MEDEL, rng)})
		Motor.Fas.CHICAGO:
			k.skicka({"t": "chicago", "ja": Robot.valj_chicago(vy, Robot.MEDEL, rng)})
		Motor.Fas.STICK:
			k.skicka({"t": "spela", "kort": Robot.valj_kort(vy, Robot.MEDEL, rng)})
		_:
			return
	skickat = true
