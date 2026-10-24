extends RefCounted
## Gemensamt för onlinespel: serveradresser, JSON-hjälp och filtrering av motorns händelser
## så att varje spelare bara får veta sin egen hand och det som är offentligt.

## Lokal server (för utveckling och tester): starta med  Godot --headless --path . -- --server --port=9080
const SERVER_LOKAL := "ws://localhost:9080"
## Produktionsservern (Render). Ändra till adressen Render ger tjänsten, med wss:// framför.
const SERVER_PRODUKTION := "wss://chicagospel.onrender.com"
## Webbadressen där webbspelet ligger (t.ex. GitHub Pages). Används för länken som datorversionen kopierar.
## På webben används sidans egen adress automatiskt.
const WEBB_ADRESS := ""

const Motor := preload("res://scripts/motor.gd")

const KODTECKEN := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const KASTTYPER := ["vattenballong", "tomat", "tarta", "snoboll", "flygplan", "ros", "hjarta", "krona", "konfetti", "sexsju"]


## Vad en robot svarar med när någon kastat på den: hälsningar besvaras vänligt, kast med kast.
static func robotsvar(typ: String, r: RandomNumberGenerator) -> String:
	if typ in ["ros", "hjarta", "krona", "konfetti", "sexsju"]:
		return ["ros", "hjarta", "konfetti"][r.randi_range(0, 2)]
	return ["vattenballong", "tomat", "tarta", "snoboll", "flygplan"][r.randi_range(0, 4)]


## Vilken server klienten ska ansluta till.
static func server_url() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--server-url="):
			return a.substr(13)
	if OS.has_feature("web"):
		var fran_sida = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('server') || ''", true)
		if fran_sida is String and fran_sida != "":
			return fran_sida
		var proto = JavaScriptBridge.eval("window.location.protocol", true)
		return SERVER_PRODUKTION if proto == "https:" else SERVER_LOKAL
	if OS.has_feature("template"):
		return SERVER_PRODUKTION
	return SERVER_LOKAL


## Bordskoden från ?bord=KOD i webbläsarens adress (tom om ingen).
static func bord_fran_adress() -> String:
	if not OS.has_feature("web"):
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--bord="):
				return a.substr(7).to_upper()
		return ""
	var k = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('bord') || ''", true)
	return str(k).to_upper() if k != null else ""


## Delbar länk till ett bord.
static func lank(kod: String) -> String:
	if OS.has_feature("web"):
		var bas = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		return "%s?bord=%s" % [bas, kod]
	if WEBB_ADRESS != "":
		return "%s?bord=%s" % [WEBB_ADRESS, kod]
	return kod


## JSON ger flyttal för alla tal. Gör om heltalsvärden till int rekursivt.
static func heltal(v):
	if v is float and v == floorf(v) and absf(v) < 1e15:
		return int(v)
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(heltal(x))
		return a
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = heltal(v[k])
		return d
	return v


static func avkoda(text: String):
	var d = JSON.parse_string(text)
	if d == null:
		return null
	return heltal(d)


## Motorns händelse som spelare p får se. Andras kort ersätts med -1.
static func filtrera(e: Dictionary, p: int) -> Dictionary:
	var u := e.duplicate(true)
	match e.typ:
		"giv":
			if e.spelare != p:
				u.kort = -1
		"byte":
			if e.spelare != p:
				var s: Array = []
				for c in e.slangda:
					s.append(-1)
				var ny: Array = []
				for c in e.nya:
					ny.append(-1)
				u.slangda = s
				u.nya = ny
		"vinst", "giv_slut":
			pass
	return u


## Det offentliga läget plus spelarens egen vy. Innehåller aldrig andras kort.
static func tillstand(m, p: int) -> Dictionary:
	var vy: Dictionary = m.vy(p)
	vy.erase("regler")
	return {
		"fas": m.fas,
		# under chicagofrågan är det hemligt vem som får ropa
		"tur": m.tur if m.fas != Motor.Fas.CHICAGO or m.tur == p else -1,
		"givare": m.givare,
		"giv_nr": m.giv_nr,
		"byte_nr": m.byte_nr,
		"poangsatts": m.fas == Motor.Fas.BYTE and m.poangsatts_bytet(),
		"stick": m.stick.duplicate(true),
		"stick_nr": m.stick_nr,
		"chicago": m.chicago,
		"chicago_sprack": m.chicago_sprack,
		"poang": m.poang.duplicate(),
		"vinnare": m.vinnare,
		"chicago_tagen": m.chicago_tagen.duplicate(),
		"lek": m.lek.size(),
		"slang": m.slangda.size(),
		"egen": vy,
	}
