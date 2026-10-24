extends RefCounted
## Stand-in för motor.gd när man spelar online. main.gd använder samma fält och funktioner som lokalt,
## men läget kommer från servern i "steg" (händelser + tillstånd) och dragen skickas till servern.
## Varje steg tillämpas först när grafiken spelar upp det, så läget följer animeringarna precis som lokalt.

const Motor := preload("res://scripts/motor.gd")

var klient
var regler
var namn: Array = []
var n := 0
var jag := 0
var fas: int = Motor.Fas.INTE_STARTAD
var tur := 0
var givare := 0
var giv_nr := 0
var byte_nr := 0
var poangsatts := false
var stick: Array = []
var stick_nr := 0
var chicago := -1
var chicago_sprack := false
var poang: Array = []
var vinnare := -1
var chicago_tagen: Array = []
var egen := {}  # spelarens egen vy från servern
var ko: Array = []  # steg som inte spelats upp än
var skickat := false  # ett drag är skickat och väntar på svar


func lagg_till(steg: Dictionary) -> void:
	ko.append(steg)


func har_mer() -> bool:
	return not ko.is_empty()


func tillampa(s: Dictionary) -> void:
	fas = s.fas
	tur = s.tur
	givare = s.givare
	giv_nr = s.giv_nr
	byte_nr = s.byte_nr
	poangsatts = s.poangsatts
	stick = s.stick
	stick_nr = s.stick_nr
	chicago = s.chicago
	chicago_sprack = s.chicago_sprack
	poang = s.poang
	vinnare = s.vinnare
	chicago_tagen = s.get("chicago_tagen", [])
	egen = s.egen
	skickat = false


## Nästa stegs händelser. Läget sätts samtidigt.
func ta_handelser() -> Array:
	if ko.is_empty():
		return []
	var st: Dictionary = ko.pop_front()
	tillampa(st.s)
	return st.h


func min_tur() -> bool:
	return not skickat and ko.is_empty() and tur == jag and (fas == Motor.Fas.BYTE or fas == Motor.Fas.CHICAGO or fas == Motor.Fas.STICK)


func vy(p: int) -> Dictionary:
	var v := egen.duplicate(true)
	v["regler"] = regler
	return v


func max_byte(_p: int) -> int:
	return int(egen.get("max_byte", 0))


func poangsatts_bytet() -> bool:
	return poangsatts


func tillatna(_p: int) -> Array:
	return egen.get("tillatna", [])


func ny_giv() -> void:
	pass


func byt(_p: int, kort: Array) -> bool:
	skickat = true
	klient.skicka({"t": "byt", "kort": kort})
	return true


func ropa_chicago(_p: int, ja: bool) -> bool:
	skickat = true
	klient.skicka({"t": "chicago", "ja": ja})
	return true


func spela(_p: int, c: int) -> bool:
	skickat = true
	klient.skicka({"t": "spela", "kort": c})
	return true
