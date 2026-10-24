extends Node
## WebSocket-klient för onlinespel. Skickar och tar emot JSON och sänder signalen `meddelande` för allt som kommer.

const Natverk := preload("res://scripts/natverk.gd")

signal meddelande(d: Dictionary)
signal ansluten
signal frankopplad

var ws := WebSocketPeer.new()
var url := ""
var oppen := false
var ko: Array = []  # meddelanden som väntar på att anslutningen öppnas
var logg: Array = []  # alla mottagna meddelanden (för tester)
var spara_logg := false


func anslut(adress: String) -> void:
	url = adress
	ws = WebSocketPeer.new()
	ws.inbound_buffer_size = 1024 * 1024
	ws.outbound_buffer_size = 256 * 1024
	oppen = false
	var e := ws.connect_to_url(adress)
	if e != OK:
		frankopplad.emit()


func koppla_fran() -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN or ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		ws.close()
	oppen = false
	ko.clear()


func skicka(d: Dictionary) -> void:
	if oppen:
		ws.send_text(JSON.stringify(d))
	else:
		ko.append(d)


func ar_ansluten() -> bool:
	return oppen


func _process(_dt: float) -> void:
	if url == "":
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not oppen:
			oppen = true
			for d in ko:
				ws.send_text(JSON.stringify(d))
			ko.clear()
			ansluten.emit()
		while ws.get_available_packet_count() > 0:
			var d = Natverk.avkoda(ws.get_packet().get_string_from_utf8())
			if d is Dictionary:
				if spara_logg:
					logg.append(d)
				meddelande.emit(d)
	elif st == WebSocketPeer.STATE_CLOSED:
		if oppen or url != "":
			var var_oppen := oppen
			oppen = false
			url = ""
			if var_oppen or true:
				frankopplad.emit()
