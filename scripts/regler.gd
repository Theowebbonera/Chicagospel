extends RefCounted
## Alla regelinställningar för Chicago. Standard är Theos husregler (se README).
## LISTA beskriver varje inställning så att menyn kan byggas automatiskt.

const SPARFIL := "user://chicago.cfg"
## Version 3 = husreglerna som standard. Äldre sparfiler har andra standardvärden och läses inte in.
const VERSION := 3

# --- partiet
var malpoang := 52
# --- poängtabell för pokerhänder
var p_par := 1
var p_tva_par := 2
var p_triss := 3
var p_stege := 4
var p_farg := 5
var p_kak := 6
var p_fyrtal := 8
var p_fargstege := 10
var p_royal := 52
var fyrtal_nollstaller := true  # fyrtal nollställer alla andras totalpoäng
# --- när pokerhänderna poängsätts
var poang_vid_given := 1  # 0 nej, 1 ja (givens hand innan något byte), 2 ja med dubbla poäng
var poang_byten := 0  # 0 inga poäng efter bytena, 1 efter varje byte utom det sista, 2 efter varje byte
var poang_efter_stick := true  # handen man spelade sticket med poängsätts efter sticket
var visa_vid_rundslut := true  # rundans poäng visas och läggs till först när sticket är klart
var lika_regel := 0  # 0 den som är först i tur efter given, 1 ingen får poäng, 2 alla med lika hand får poäng
var ess_lag := true
var royal_vinner := false
# --- byten
var antal_byten := 3
var max_byte := 5
var kopstopp_pa := true
var kopstopp := 41  # den som har minst så här många poäng får inte byta
var blanda_om := true
# --- sticken
var stick_poang := 2
var tvaa_bonus := true
var tvaa_poang := 5
var vinna_pa_stick := true
# --- chicago
var chicago_tillatet := true
var chicago_poang := 15
var chicago_straff := 15
var chicago_min := 15
var chicago_en_gang := true  # den som lyckats med Chicago får inte ropa igen i partiet
var chicago_spelar_ut := true
var chicago_avbryt := false

const LISTA := [
	{"grupp": "Partiet"},
	{"namn": "malpoang", "text": "Målpoäng", "typ": "tal", "min": 5, "max": 500, "hjalp": "Den som först når målpoängen vinner partiet. Det avgörs när rundans poäng redovisas."},
	{"namn": "vinna_pa_stick", "text": "Får vinna på sticket", "typ": "bool", "hjalp": "Av: poäng från sista sticket och Chicago kan inte ta en spelare i mål, man stannar på målpoängen minus 1 och måste gå ut på en pokerhand."},
	{"namn": "royal_vinner", "text": "Royal straight flush vinner direkt", "typ": "bool", "hjalp": "Den som får royal straight flush vinner partiet oavsett poäng."},
	{"grupp": "Poängtabell"},
	{"namn": "p_par", "text": "Par", "typ": "tal", "min": 0, "max": 100},
	{"namn": "p_tva_par", "text": "Två par", "typ": "tal", "min": 0, "max": 100},
	{"namn": "p_triss", "text": "Triss", "typ": "tal", "min": 0, "max": 100},
	{"namn": "p_stege", "text": "Stege", "typ": "tal", "min": 0, "max": 100},
	{"namn": "p_farg", "text": "Färg", "typ": "tal", "min": 0, "max": 100},
	{"namn": "p_kak", "text": "Kåk", "typ": "tal", "min": 0, "max": 100},
	{"namn": "p_fyrtal", "text": "Fyrtal", "typ": "tal", "min": 0, "max": 100},
	{"namn": "fyrtal_nollstaller", "text": "Fyrtal nollställer alla andra", "typ": "bool", "hjalp": "Den som får poäng för fyrtal gör att alla andra spelares totalpoäng blir 0."},
	{"namn": "p_fargstege", "text": "Färgstege", "typ": "tal", "min": 0, "max": 100},
	{"namn": "p_royal", "text": "Royal straight flush", "typ": "tal", "min": 0, "max": 500},
	{"grupp": "När händerna poängsätts"},
	{"namn": "poang_vid_given", "text": "Givens hand (innan något byte)", "typ": "val", "val": ["Nej", "Ja", "Ja, dubbla poäng"], "hjalp": "De utdelade korten poängsätts innan första bytet. Räknas även om någon ropar Chicago."},
	{"namn": "poang_efter_stick", "text": "Handen man spelade sticket med", "typ": "bool", "hjalp": "Händerna som de såg ut när sticken började poängsätts efter sticket. Lyckas någon med Chicago delas de poängen inte ut."},
	{"namn": "poang_byten", "text": "Poäng efter bytena", "typ": "val", "val": ["Nej", "Efter varje byte utom det sista", "Efter varje byte"], "hjalp": "Äldre variant där händerna poängsätts direkt efter bytena."},
	{"namn": "visa_vid_rundslut", "text": "Visa rundans poäng först efter sticket", "typ": "bool", "hjalp": "Poängen under rundan hålls hemliga och läggs till totalen när sticket är klart. Köpstopp och rätt att ropa Chicago räknas ändå på den löpande totalen."},
	{"namn": "lika_regel", "text": "Vid lika händer", "typ": "val", "val": ["Först i tur efter given vinner", "Ingen får poäng", "Alla med lika hand får poäng"], "hjalp": "Händerna jämförs i hemlighet i turordning med början hos spelaren efter given. Inga kort visas."},
	{"namn": "ess_lag", "text": "Ess kan vara lågt i stege (E-2-3-4-5)", "typ": "bool"},
	{"grupp": "Byten"},
	{"namn": "antal_byten", "text": "Antal bytesomgångar", "typ": "tal", "min": 0, "max": 5},
	{"namn": "max_byte", "text": "Högst antal kort per byte", "typ": "tal", "min": 1, "max": 5},
	{"namn": "kopstopp_pa", "text": "Köpstopp", "typ": "bool", "hjalp": "Den som har nått gränsen nedan får inte byta kort utan står över bytena."},
	{"namn": "kopstopp", "text": "Köpstopp vid poäng", "typ": "tal", "min": 1, "max": 500},
	{"namn": "blanda_om", "text": "Blanda om slänghögen när talongen tar slut", "typ": "bool", "hjalp": "Av: man kan bara byta så många kort som finns kvar i talongen."},
	{"grupp": "Sticken"},
	{"namn": "stick_poang", "text": "Sista sticket", "typ": "tal", "min": 0, "max": 100, "hjalp": "Poäng till den som tar sista sticket."},
	{"namn": "tvaa_bonus", "text": "Särskild poäng för att gå ut på en tvåa", "typ": "bool", "hjalp": "Tas sista sticket med en tvåa ger det poängen nedan i stället för vanlig stickpoäng."},
	{"namn": "tvaa_poang", "text": "Ut på en tvåa", "typ": "tal", "min": 0, "max": 100},
	{"grupp": "Chicago"},
	{"namn": "chicago_tillatet", "text": "Chicago får ropas", "typ": "bool"},
	{"namn": "chicago_poang", "text": "Poäng för lyckad Chicago", "typ": "tal", "min": 0, "max": 200, "hjalp": "Lyckad Chicago ger bara dessa poäng: inga stickpoäng och ingen poäng för handen efter sticket."},
	{"namn": "chicago_straff", "text": "Avdrag för misslyckad Chicago", "typ": "tal", "min": 0, "max": 200, "hjalp": "Stickpoäng och handpoäng efter sticket räknas ändå."},
	{"namn": "chicago_min", "text": "Minsta poäng för att få ropa", "typ": "tal", "min": -100, "max": 500, "hjalp": "Räknas på den löpande totalen, alltså med poängen från givens hand."},
	{"namn": "chicago_en_gang", "text": "Chicago bara en gång per parti", "typ": "bool", "hjalp": "Den som har lyckats med Chicago får inte ropa igen, inte ens efter att ha blivit nollställd. En misslyckad Chicago förbrukar inte rätten."},
	{"namn": "chicago_spelar_ut", "text": "Den som ropar spelar ut först", "typ": "bool"},
	{"namn": "chicago_avbryt", "text": "Given avbryts när Chicago spricker", "typ": "bool", "hjalp": "Av (standard): sticken spelas klart."},
]


func kat_poang(kat: int) -> int:
	if kat <= 0 or kat > 9:
		return 0
	return int(get(["", "p_par", "p_tva_par", "p_triss", "p_stege", "p_farg", "p_kak", "p_fyrtal", "p_fargstege", "p_royal"][kat]))


func namnlista() -> Array:
	var ut: Array = []
	for d in LISTA:
		if d.has("namn"):
			ut.append(d.namn)
	return ut


func till_dict() -> Dictionary:
	var d := {}
	for k in namnlista():
		d[k] = get(k)
	return d


func fran_dict(d: Dictionary) -> void:
	for k in namnlista():
		if d.has(k):
			var gammalt = get(k)
			if gammalt is bool:
				set(k, bool(d[k]))
			else:
				set(k, int(d[k]))


func kopia():
	var r = get_script().new()
	r.fran_dict(till_dict())
	return r


func aterstall() -> void:
	fran_dict(get_script().new().till_dict())


## Klassiska svenska regler (som i första versionen): poäng efter byte 1 och 2, ingen sluthand,
## fyrtal 7 utan nollställning, färgstege 8, inget köpstopp, Chicago utan minimipoäng.
func klassiska() -> void:
	aterstall()
	p_fyrtal = 7
	p_fargstege = 8
	fyrtal_nollstaller = false
	poang_vid_given = 0
	poang_byten = 1
	poang_efter_stick = false
	visa_vid_rundslut = false
	kopstopp_pa = false
	chicago_min = 0
	chicago_en_gang = false
	chicago_avbryt = true


## Behålls för knappen i menyn: fyrtal 8, färgstege 10.
func theos_tabell() -> void:
	p_fyrtal = 8
	p_fargstege = 10


func spara(cf: ConfigFile) -> void:
	cf.set_value("regler", "version", VERSION)
	for k in namnlista():
		cf.set_value("regler", k, get(k))


func ladda(cf: ConfigFile) -> void:
	var version := int(cf.get_value("regler", "version", 1))
	# äldre sparfiler hade andra standardregler: börja om från husreglerna
	if version < VERSION:
		return
	var d := {}
	for k in namnlista():
		if cf.has_section_key("regler", k):
			d[k] = cf.get_value("regler", k)
	fran_dict(d)


## Kort sammanfattning av reglerna som de är inställda, för regelsidan i spelet.
func beskrivning() -> String:
	var t := ""
	t += "[b]Mål:[/b] först till %d poäng. Bara poäng, inga insatser.\n\n" % malpoang
	t += "[b]Given:[/b] alla får 5 kort. Spelaren efter given börjar och turen går medsols.\n\n"
	var nar: Array = []
	if poang_vid_given > 0:
		nar.append("givens hand innan något byte%s" % (" (dubbla poäng)" if poang_vid_given == 2 else ""))
	if poang_byten == 1:
		nar.append("efter varje byte utom det sista")
	elif poang_byten == 2:
		nar.append("efter varje byte")
	if poang_efter_stick:
		nar.append("handen man spelade sticket med, efter sticket")
	t += "[b]Poäng för pokerhänder:[/b] %s. Bara den bästa handen vid bordet får poäng, och högt kort ger inget." % (", ".join(nar) if not nar.is_empty() else "inga")
	if visa_vid_rundslut:
		t += " Rundans poäng hålls hemliga och visas och läggs till totalen först när sticket är klart."
	t += " Inga kort vänds: spelet säger bara vem som tar poängen och vilken sorts hand det är (till exempel \"Anna: färg, 5 poäng\")."
	var lika: String = ["får den som är först i tur efter given poängen", "får ingen poäng", "får alla med lika hand poäng"][lika_regel]
	t += " Vid exakt lika hand %s.\n" % lika
	t += "Par %d · Två par %d · Triss %d · Stege %d · Färg %d · Kåk %d · Fyrtal %d · Färgstege %d · Royal straight flush %d\n" % [p_par, p_tva_par, p_triss, p_stege, p_farg, p_kak, p_fyrtal, p_fargstege, p_royal]
	if fyrtal_nollstaller:
		t += "Fyrtal nollställer alla andra spelares totalpoäng. "
	t += "Ess räknas högt%s.%s\n\n" % [" och lågt i stegen E-2-3-4-5" if ess_lag else "", " Royal straight flush vinner partiet direkt." if royal_vinner else ""]
	if antal_byten > 0:
		t += "[b]Byten:[/b] %d bytesomgångar där man byter 0–%d kort." % [antal_byten, max_byte]
		if kopstopp_pa:
			t += " Köpstopp: den som har %d poäng eller mer (räknat med rundans poäng hittills) får inte byta utan står över." % kopstopp
		t += "\n\n"
	else:
		t += "[b]Byten:[/b] inga byten.\n\n"
	t += "[b]Sticken:[/b] efter sista bytet spelas fem stick utan trumf. Man måste bekänna färg om man kan, högsta kortet i utspelad färg tar sticket och den som tar sticket spelar ut nästa. Sista sticket ger %d poäng" % stick_poang
	if tvaa_bonus:
		t += ", och %d poäng om det tas med en tvåa (att gå ut på en tvåa)" % tvaa_poang
	t += ".%s\n\n" % ("" if vinna_pa_stick else " Man kan inte vinna partiet på sticket, man stannar på %d poäng." % (malpoang - 1))
	if chicago_tillatet:
		t += "[b]Chicago:[/b] före första sticket får en spelare ropa Chicago och lovar då att ta alla fem stick."
		if chicago_min != 0:
			t += " Man måste ha minst %d poäng (räknat med rundans poäng hittills) för att få ropa." % chicago_min
		t += " Lyckas det ger det %d poäng och inget annat efter sticket: varken stickpoäng eller handpoäng delas ut. Spricker det dras %d poäng, men stick- och handpoäng efter sticket räknas ändå. Poängen för givens hand räknas alltid." % [chicago_poang, chicago_straff]
		if chicago_en_gang:
			t += " Den som har lyckats med Chicago får inte ropa igen i partiet, inte ens efter att ha blivit nollställd. En misslyckad Chicago förbrukar inte rätten."
		if chicago_spelar_ut:
			t += " Den som ropat spelar ut först."
		t += " " + ("Given avbryts direkt om ropet spricker." if chicago_avbryt else "Sticken spelas klart även om ropet spricker.")
	else:
		t += "[b]Chicago:[/b] får inte ropas."
	return t
