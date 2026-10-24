extends Node
## Alla ljud syntetiseras i kod: kortknäpp, kort mot filten, blandning (riffle), glid, poängklang, fanfar m.m.

var ljud := {}
var roster: Array = []
var nasta := 0
var volym_db := 0.0
var tyst := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4242
	ljud["kort"] = _knapp(0.05, 3200.0, 0.55)
	ljud["slag"] = _slag()
	ljud["kast"] = _kast()
	ljud["plask"] = _plask()
	ljud["kast_luft"] = _sus()
	ljud["splatt"] = _splatt()
	ljud["small"] = _small()
	ljud["puff"] = _puff()
	ljud["kyss"] = _kyss()
	ljud["sexsju"] = _sexsju()
	ljud["blanda"] = _riffle(0.85)
	ljud["glid"] = _glid(0.32)
	ljud["poang"] = _klang([1046.5, 1568.0], 0.9, 0.32, 0.07)
	ljud["stor_poang"] = _klang([784.0, 988.0, 1175.0, 1568.0], 1.4, 0.34, 0.08)
	ljud["chicago"] = _fanfar([392.0, 523.25, 659.25, 783.99], 0.11, 1.3)
	ljud["vinst"] = _fanfar([523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5], 0.13, 2.2)
	ljud["sprack"] = _sprack()
	ljud["klick"] = _knapp(0.018, 5000.0, 0.25)
	ljud["fel"] = _dunk()
	ljud["tur"] = _klang([880.0], 0.35, 0.16, 0.0)
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		roster.append(p)


func spela(namn: String, tonhojd := 1.0, db := 0.0, slump := 0.06) -> void:
	if tyst or not ljud.has(namn):
		return
	var p: AudioStreamPlayer = roster[nasta]
	nasta = (nasta + 1) % roster.size()
	p.stream = ljud[namn]
	p.pitch_scale = tonhojd * (1.0 + rng.randf_range(-slump, slump))
	p.volume_db = db + volym_db
	p.play()


# ------------------------------------------------------------------ syntes
## Kortknäpp: kort brusstöt genom ett enkelt bandpass, snabb avklingning.
func _knapp(dur: float, f: float, vol: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var a := clampf(TAU * f / rate, 0.0, 1.0)
	for i in n:
		var t := float(i) / rate
		var x := rng.randf_range(-1.0, 1.0)
		lp += a * (x - lp)
		lp2 += a * 0.5 * (lp - lp2)
		var bp := lp - lp2
		s[i] = bp * exp(-t * 90.0) * vol * 2.2 * minf(1.0, t * 3000.0)
	return _wav(s, rate)


## Kort som läggs mot filten: dovt brus och en mjuk duns.
func _slag() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.16)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += 0.25 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = (lp * 1.2 * exp(-t * 45.0) + sin(TAU * 140.0 * t) * 0.35 * exp(-t * 38.0)) * minf(1.0, t * 2500.0) * 0.7
	return _wav(s, rate)


## Riffle-blandning: tätt följande knäpp som först tätnar och sedan klingar av.
func _riffle(dur: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var t := 0.03
	while t < dur - 0.06:
		var fas := t / dur
		var start := int(t * rate)
		var len := int(rate * 0.012)
		var f := rng.randf_range(2500.0, 4200.0)
		var a := TAU * f / rate
		var lp := 0.0
		var amp := 0.35 + 0.4 * sin(PI * fas)
		for i in len:
			if start + i >= n:
				break
			lp += clampf(a, 0.0, 1.0) * (rng.randf_range(-1.0, 1.0) - lp)
			s[start + i] += lp * amp * exp(-float(i) / rate * 400.0)
		t += lerpf(0.022, 0.009, sin(PI * fas)) * rng.randf_range(0.7, 1.3)
	# avslutande "brrt" när korten trycks ihop
	var bs := int(rate * (dur - 0.08))
	for i in range(bs, n):
		var tt := float(i - bs) / rate
		s[i] += rng.randf_range(-1.0, 1.0) * 0.25 * exp(-tt * 40.0)
	return _wav(s, rate)


## Kortkast: kortet glider kort över filten (bandpassat brus som sveper), ett papperssnärt när kanten
## slår i och en mjuk duns av filten. Tonhöjden varieras vid uppspelning.
func _kast() -> AudioStreamWAV:
	var rate := 44100
	var dur := 0.26
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var glid_slut := 0.085
	var snart := 0.075
	for i in n:
		var t := float(i) / rate
		var x := rng.randf_range(-1.0, 1.0)
		# glid: bandpass som sveper nedåt, tonar in och ut
		var f := lerpf(5200.0, 2400.0, clampf(t / glid_slut, 0.0, 1.0))
		var a := clampf(TAU * f / rate, 0.0, 1.0)
		lp += a * (x - lp)
		lp2 += a * 0.35 * (lp - lp2)
		var glid := (lp - lp2) * smoothstep(0.0, 0.02, t) * (1.0 - smoothstep(glid_slut - 0.02, glid_slut + 0.03, t)) * 0.55
		# snärt: kort, ljus knäpp när kortet lägger sig
		var ts := t - snart
		var snarten := 0.0
		if ts >= 0.0:
			snarten = (x - lp) * exp(-ts * 260.0) * 0.9
		# duns: låg ton i filten
		var duns := 0.0
		if ts >= 0.0:
			duns = sin(TAU * 105.0 * ts) * exp(-ts * 45.0) * 0.42 + sin(TAU * 190.0 * ts) * exp(-ts * 70.0) * 0.12
		s[i] = (glid + snarten + duns) * 0.9
	return _wav(s, rate)


## Vattenballong som spricker: blöt smäll och skvätt.
func _plask() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.7)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += 0.18 * (rng.randf_range(-1.0, 1.0) - lp)
		var small := lp * exp(-t * 9.0) * 1.3
		var pop := sin(TAU * lerpf(420.0, 120.0, minf(t * 12.0, 1.0)) * t) * exp(-t * 30.0) * 0.6
		s[i] = small + pop
	# droppar
	for k in 14:
		var st := int(rate * rng.randf_range(0.08, 0.6))
		var f := rng.randf_range(900.0, 2200.0)
		for i in int(rate * 0.04):
			if st + i >= n:
				break
			var t := float(i) / rate
			s[st + i] += sin(TAU * f * (1.0 + t * 8.0) * t) * exp(-t * 90.0) * 0.18
	return _wav(s, rate)


## Sus genom luften när något kastas.
func _sus() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += (0.05 + 0.1 * sin(PI * t / 0.5)) * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = lp * sin(PI * t / 0.5) * 0.8
	return _wav(s, rate)


## Tomat som träffar: dov blöt duns.
func _splatt() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.35)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += 0.1 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = (lp * 1.6 + sin(TAU * 80.0 * t) * 0.5) * exp(-t * 16.0)
	return _wav(s, rate)


## Tårtsmällare: kort smäll och prassel.
func _small() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.6)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		var x := rng.randf_range(-1.0, 1.0)
		s[i] = x * exp(-t * 40.0) * 0.9 + x * 0.12 * exp(-t * 4.0) * (0.5 + 0.5 * sin(TAU * 31.0 * t))
	return _wav(s, rate)


## Snöboll: mjuk puff.
func _puff() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.3)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += 0.06 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = lp * 3.0 * exp(-t * 14.0) * minf(1.0, t * 300.0)
	return _wav(s, rate)


## Fingerkyss: kort "smack" och en liten glad ton.
func _kyss() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.5)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		var smack := rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.7
		var ton := 0.0
		if t > 0.08:
			var tt := t - 0.08
			ton = sin(TAU * (900.0 + 500.0 * tt) * tt) * exp(-tt * 7.0) * 0.25
		s[i] = smack + ton
	return _wav(s, rate)


## 6-7: två studsiga toner som gungar ("sex", "sju") med vibrato. Ingen röst.
func _sexsju() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var toner := [[0.0, 587.0, 440.0], [0.35, 698.0, 523.0]]
	for tn in toner:
		var st := int(tn[0] * rate)
		var ph := 0.0
		for i in range(st, mini(n, st + int(rate * 0.45))):
			var t := float(i - st) / rate
			var f: float = lerpf(tn[1], tn[2], minf(t / 0.12, 1.0)) * (1.0 + 0.03 * sin(TAU * 9.0 * t))
			ph = fmod(ph + f / rate, 1.0)
			var v := sin(TAU * ph) * 0.6 + (2.0 * ph - 1.0) * 0.15
			s[i] += v * minf(1.0, t * 80.0) * exp(-t * 6.0) * 0.5
	return _wav(s, rate)


## Glid: mjukt brus som sveper (kort som dras ihop över filten).
func _glid(dur: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var fas := t / dur
		lp += (0.08 + 0.1 * fas) * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = lp * sin(PI * fas) * 0.9
	return _wav(s, rate)


## Klockklang med några deltoner, tonerna kan läggas ut i tid som ett arpeggio.
func _klang(freqs: Array, dur: float, vol: float, spread: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	var parts := [[1.0, 1.0, 5.0], [2.0, 0.35, 8.0], [3.01, 0.15, 12.0], [4.2, 0.06, 18.0]]
	for fi in freqs.size():
		var f: float = freqs[fi]
		var off := int(fi * spread * rate)
		for i in range(off, n):
			var t := float(i - off) / rate
			var v := 0.0
			for p in parts:
				v += p[1] * sin(TAU * f * p[0] * t) * exp(-t * p[2])
			s[i] += v * minf(1.0, t * 600.0) * vol / sqrt(freqs.size())
	return _wav(s, rate)


## Fanfar: mjuka sågtandstoner genom lågpass, ton för ton och sedan ett ackord.
func _fanfar(toner: Array, steg: float, dur: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * dur)
	var s := PackedFloat32Array()
	s.resize(n)
	for k in toner.size():
		var f: float = toner[k]
		var start := int(k * steg * rate)
		var lp := 0.0
		var ph := 0.0
		for i in range(start, n):
			var t := float(i - start) / rate
			ph = fmod(ph + f / rate, 1.0)
			var saw := ph * 2.0 - 1.0
			lp += 0.12 * (saw - lp)
			var env := minf(1.0, t * 40.0) * exp(-t * (1.6 if k == toner.size() - 1 else 3.2))
			s[i] += (lp * 0.5 + sin(TAU * f * t) * 0.5) * env * 0.22
	return _wav(s, rate)


func _sprack() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.9)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var f := lerpf(330.0, 140.0, t / 0.9)
		ph = fmod(ph + f / rate, 1.0)
		lp += 0.1 * ((ph * 2.0 - 1.0) - lp)
		s[i] = lp * 0.5 * minf(1.0, t * 30.0) * exp(-t * 2.5) * (0.8 + 0.2 * sin(TAU * 6.0 * t))
	return _wav(s, rate)


func _dunk() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.18)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / rate
		s[i] = (sin(TAU * 150.0 * t) * 0.6 + rng.randf_range(-1, 1) * 0.12) * exp(-t * 28.0) * 0.5
	return _wav(s, rate)


func _wav(s: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
