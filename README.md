# Chicago (Godot 4.7: dator, webb och online)

Svensk Chicago, pokervarianten med byten och stick, vid ett 3D-kortbord med fyra realistiska figurer (Kevin, Theo, Lukas och Adam) på platserna. Spelet är bara online: du skapar ett bord och delar länken, och dina vänner väljer sin figur och hamnar i lobbyn. Det finns inga robotar och inget lokalt spel. Det går bara om poäng, utan insatser. Bordet, figurerna, ljuset och ljuden byggs i kod. De klädda korten är David Bellots SVG-cards (LGPL-2.1), där kungen har krona och skägg, knekten hatt och damen krona och slöja, med spelets egna svenska hörnindex (Kn, D, K, E).

- **Spela:** `spela.bat` · **Editorn:** `redigera.bat` · **Tester:** `testa.bat`
- **Färdiga byggen:** `build/windows/Chicago.exe` (en fil) och `build/web/` (webbversionen).
- **Handen:** de egna korten ligger bredvid varandra så att hela kortet syns, och handen krymps och centreras så att den får plats mellan poängtavlan och åtgärdsrutan.
- **Styrning:** klicka på kort för att välja vilka som ska bytas och tryck **Byt**. I sticken klickar du på kortet du vill spela, och otillåtna kort är mörkare. Tangenterna 1–5 väljer kort, Enter bekräftar och Esc pausar.
- **Kasta och hälsa:** klicka på en annan spelares figur eller namn. Knappen **6-7** uppe till höger gör 6-7 själv.

## Theos husregler (standard)
Allt går att ändra under **Skapa bord**. Knappen **Klassiska regler** ger de vanligaste svenska reglerna i stället.

| Regel | Standard |
|---|---|
| Målpoäng och vinst | 52, **och man måste ha tagit Chicago för att vinna** (inställning, på; av i klassiska regler). Når man 52 utan Chicago fortsätter partiet: poängen räknas vidare, köpstoppet gäller och man kan fortfarande ropa Chicago. Vinsten kontrolleras varje gång poäng läggs till, både vid givens hand och efter sticket. Uppfyller flera villkoren vinner högst total, och vid lika vinner den som är först i tur efter given. En lyckad Chicago som tar spelaren över 52 vinner. Poängtavlan visar "behöver Chicago" för den som har nått målet utan Chicago. Kravet gäller bara när Chicago får ropas, och royal straight flush (om "vinner direkt" är på) vinner oavsett. |
| Poängtabell | par 1, två par 2, triss 3, stege 4, färg 5, kåk 6, **fyrtal 8**, **färgstege 10**, royal straight flush 52 |
| Fyrtal | **nollställer alla andra spelares totalpoäng** (inställning, på) |
| När händerna poängsätts | **efter varje giv**: varje utdelning av kort räknas som en giv, alltså första given, byte 1 och byte 2 (med standard tre byten). Pokerhanden poängsätts och **visas direkt** efter varje sådan giv. Efter det sista bytet följer stick-rundan, där **handen man spelade sticket med** poängsätts efter sticket. Den som har köpstopp byter inte, men hans hand poängsätts ändå vid varje giv. Inställningarna heter "Givens hand", "Poäng efter bytena: efter varje byte utom det sista" och "Handen man spelade sticket med". |
| Visning | **poängen efter given, byte 1 och byte 2 visas och läggs till direkt**. Ett fyrtal vid given nollställer de andra direkt i poängtavlan. **Bara stick-rundan** (sluthandens poäng, sista sticket eller tvåan, Chicago +15 eller −15) visas och läggs till när sticket är klart. |
| Bara bästa handen | bara den bästa handen vid bordet får poäng, och högt kort ger inget. Vid exakt lika får den som är först i tur efter given poängen. |
| Köpstopp | den som har **41 poäng eller mer** får inte byta och står över bytena (inställbart) |
| Byten | 3 omgångar, 0–5 kort |
| 1 upp | byter man **bara ett kort** vänds talongens översta kort upp så att alla ser det. Man väljer att **ta det**, eller att det läggs i slänghögen och man får **nästa kort dolt** (inställbart) |
| Sista sticket | 2 poäng, eller **5 poäng om det tas med en tvåa** (två egna värden, ingen faktor) |
| Chicago | får bara ropas med **minst 15 poäng**. Lyckas det ger det **+15**, och inga stickpoäng eller handpoäng efter sticket delas ut. Spricker det blir det **−15**, men spelarens stick- och handpoäng efter sticket räknas ändå. Theos exempel: −15 + sista sticket 2 + par 1 = **−12**. Givens poäng räknas alltid. |
| Chicago en gång per parti | den som har **lyckats** får inte ropa igen, inte ens efter att ha blivit nollställd av ett fyrtal. En misslyckad Chicago förbrukar inte rätten. Den som har tagit sin Chicago märks med "Chicago tagen" i poängtavlan. |

**Köpstopp och Chicago-rätt** följer den synliga totalen. Givens poäng finns redan med i den, eftersom de visas direkt. Den som når 41 genom givens poäng får alltså inte byta i samma runda, och den som når 15 vid given får ropa Chicago. Ett fyrtal vid given nollställer de andra direkt.

**Eget val:** färgstege har 10 poäng som standard, så att den är värd mer än fyrtalet (8). Det är också värdet i Theos första poängtabell.

## Dolda kort
- Det enda som syns öppet är **kortet en spelare lägger i sticket** och **din egen hand**.
- **Vid poängsättningen vänds inga kort.** Spelet säger bara till exempel "Anna: färg, 5 poäng", aldrig färger eller valörer. Lika händer avgörs i hemlighet.
- Andras händer, slängda kort, talongen och tagna stick ligger alltid med baksidan upp.
- Under Chicago-frågan visas inte vems tur det är, eftersom det skulle avslöja vem som har rätt att ropa. Köpstopp och Chicago-rätt får man bara veta om sig själv. För andra syns bara att de "står över".
- Servern skickar bara spelarens egen vy (`motor.vy(p)`). Andras kort når aldrig din dator, så ingen kan fuska.

## Realistiska figurer (Kevin, Theo, Lukas, Adam)
- Fyra figurer efter Theos bild från fjälltoppen, byggda i Blender 4.5 med MPFB (MakeHuman, CC0): kropp, hud, hår och kläder från MPFB, kläderna omfärgade efter bilden. Kepsar, glasögon, solglasögonen på Adams keps, DevEd-texten, Kevins gula handske och Adams svarta armärm modelleras i skriptet.
- Bygg om: `blender.exe -b -P blender/gubbar.py` (alla fyra, `assets/gubbar/<namn>.glb` och provbilder i `blender/prov/`), eller `-- Theo` för en, `-- --prov` för bara provbilder. Utseendet (kroppsform, ansiktsform, hudton, hårfärg, kläder, keps) står i `PERSONER` överst i skriptet.
- Skelettet (MPFB:s `game_engine`) har den sittande posen som vila. `gubbe.gd` skalar modellen till bordets mått och styr blick, skakning, gest, jubel och 6-7 genom att vrida nacke, huvud och armar. Kast, grädde, krona och droppar sitter på ett osynligt huvud som följer huvudbenet.
- De tecknade figurerna (Greta, Bosse, robot, hund, katt med flera) är borttagna; `figurer.gd` har bara de fyra. Varje fil är cirka 3,5 MB (texturer 1024 px).

## Figurer, kast och 6-7
- **4 figurer** (`scripts/figurer.gd`, byggs av `scripts/gubbe.gd`), se ovan.
- Värden väljer figur under **Skapa bord**, och den som går med väljer på figurskärmen (snurrande förhandsvisning, Föregående och Nästa). Figuren kan bytas i lobbyn. Den som inte har valt får en figur som inte redan är tagen. Är alla fyra tagna (fem eller sex spelare) får man ta en som redan används. Valet sparas i `user://chicago.cfg` och skickas via servern.
- Figurerna andas, tittar mot den som har turen, gestikulerar när de spelar, jublar vid poäng och sitter bakom bordskanten så att de inte skymmer korten.
- **Kastmenyn**
  - Kasta: vattenballong, tomat, gräddtårta, snöboll, pappersflygplan.
  - Hälsa: ros, fingerkyss, krona, konfetti, 6-7.

  Det finns 3 sekunders spärrtid.
- **6-7:** figuren håller båda handflatorna uppåt och gungar händerna i otakt med en pratbubbla och ett syntetiserat ljud. Inget av detta påverkar spelet eller visar kort.

## Spela online
1. **Värden** väljer **Skapa bord …**, skriver sitt namn, väljer figur och regler och trycker **Skapa bord**. Värden får en kod (till exempel `K7Q2`) och en lobby. Bara värden ställer in regler och ser **Starta**.
2. **Kopiera länk** och skicka den. Kompisarna öppnar `https://<din-sida>/?bord=K7Q2` och kommer **direkt** till figurskärmen, utan startskärm:
   - figurväljaren (snurrande förhandsvisning, Föregående och Nästa). Figurer som redan är tagna vid bordet visas som upptagna och hoppas över.
   - ett namnfält, förifyllt med figurens namn
   - partiets regler i läsläge
   - en stor knapp **Gå med**, som tar dem till lobbyn

   **Gå med i bord …** i menyn ger samma skärm med ett fält för koden.
3. I lobbyn syns de som har gått med, med figur och namn, och hur många platser som är kvar (högst 6). Den som har gått med ser "Väntar på att <värd> startar partiet …". Värden trycker **Starta** när minst två sitter vid bordet. Lediga platser tas bort vid start, och den som har tappat anslutningen i lobbyn är inte med.
4. Tappar någon anslutningen mitt i partiet ansluter klienten själv igen med en token som är sparad lokalt (`user://chicago_online.cfg`). Samma länk fungerar också. Är spelaren borta längre än 45 sekunder när det är dennes tur gör servern ett enkelt drag (inget byte, vid 1 upp tas kortet, ingen Chicago, lägsta tillåtna kortet), så att partiet inte står still.
5. Bord utan anslutna människor städas bort efter 10 minuter.

Servern (`scripts/server.gd`) är auktoritativ med `motor.gd` som enda sanning. Den blandar, ger och avgör stick och poäng. Varje klient får bara sin egen hand och det offentliga. Andras kort skickas aldrig: i givar och byten kommer de som `-1` (`scripts/natverk.gd`, `filtrera`/`tillstand`). Vid 1 upp är det uppvända kortet offentligt (`upp`, och `upp_svar` när det tas), medan det slängda kortet och det dolda kortet efter ett nej bara går till spelaren själv. Klienten visar dem med anonyma kortnoder som byter identitet osynligt när ett kort spelas ut. Allt valideras på servern: otillåtna drag, drag i fel tur och för tidiga kast. Bara värdens anslutning, alltså värdens token, får ändra regler och starta. Två spelare får inte ha samma figur, så länge det finns lediga figurer. Att gå med i ett pågående parti kräver token. Tappar värden anslutningen behålls värdskapet via token vid återanslutning. Före anslutning kan klienten fråga om ett bord (`bordinfo`) och får regler, värd och tagna figurer. Vid start packas platserna ihop, och var och en får sin plats på nytt (`valkommen`). Protokollet är JSON över WebSocket.

**Serveradress:** den sätts i `scripts/natverk.gd`.
- `SERVER_LOKAL` (`ws://localhost:9080`) används när spelet körs från editorn och när webbsidan körs över http, till exempel lokalt.
- `SERVER_PRODUKTION` (`wss://chicagospel.onrender.com`) används när webbsidan körs över https och i den exporterade `.exe`-filen.
- På webben kan adressen också ges med `?server=wss://...` i länken. I datorversionen går det med `-- --server-url=...`.
- `WEBB_ADRESS` är adressen till webbspelet, och den används för länken som datorversionen kopierar. På webben används sidans egen adress.

Lokal server: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --server --port=9080`. Porten kan också sättas med miljövariabeln `PORT`.

**Klient och server hör ihop:** servern och webbspelet måste uppdateras samtidigt (Render och GitHub Pages), eftersom en äldre server kräver att alla platser är fyllda innan start.

## Webbversion
- Exportprofilen **Web** körs utan trådar (nothreads) till `build/web/`, och **Windows** exporteras till `build/windows/Chicago.exe`. Båda finns i `export_presets.cfg`.
- Webben använder renderaren **Compatibility** via en webböverstyrning (`rendering_method.web`). Datorversionen behåller Forward+.
- Webben börjar med skärmen **"Klicka för att börja"**, eftersom ljud kräver ett klick. Med en `?bord=`-länk visas figurskärmen direkt i stället, och klicket på **Gå med** startar ljudet. Avsluta-knappen är dold.
- Exportera igen: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html`.
- Prova lokalt: `py -m http.server 8060 --directory build/web` och öppna `http://localhost:8060/`. Starta också den lokala servern för att spela online.
- **Skillnader i Compatibility** (`bord.gd` och andra skript):
  - **Skuggorna från lampan är avstängda**, eftersom de blev helt svarta.
  - **SSAO** och **mjuka skuggor** (`light_size`, `shadow_blur`) finns inte.
  - Glow är enklare.
  - Färgjustering, ACES, clearcoat och normalkartor fungerade i provet.
  - `instance uniform` (kortglöden) fungerar.
  - MSAA och `ALPHA_TO_COVERAGE` är begränsade i WebGL, så korthörnen blir lite skarpare.

## Mobil och iPhone (Safari)
- **Stående läge:** skärmen **"Vrid telefonen"** visas, eftersom spelet spelas liggande. Vid första trycket ber sidan om fullskärm och om att låsa till liggande (`screen.orientation.lock`). Det fungerar på Android. På iPhone Safari finns ingen fullskärm eller låsning, så där vrider man själv.
- **Liggande på telefon:** gränssnittet skalas upp (`content_scale_factor` 1.5) och huvudmenyn är kompaktare. Paneler som inte får plats krymps och går att rulla. Kastmenyn har större text.
- **Touch:** `emulate_mouse_from_touch` är på. Kort, knappar och figurer räknas om vid själva trycket, så att touch träffar rätt även utan muspekare.
- **Lättare grafik på mobil:** 3D-vyn renderas i 75 % upplösning, och 3D-MSAA är av på webben.
- **Kända orsaker till svart eller vit sida på webben, och vad som är gjort:**
  - MSAA 2D och 3D är avstängt på webben (`msaa_*.web=0`, även i kortatlasens och figurvisningens SubViewports). Det tar bort varningen "2D MSAA is not yet supported for GLES3".
  - HDR 2D, glöd och SSAO är avstängda på webben, så att inga float-renderbuffertar behövs.
  - Kortatlasen ritas i 70 % storlek på webben, vilket ger cirka 2900×1180 i stället för 4200×1680 och mindre minne.
  - Texturkomprimering för mobil (ETC2/ASTC) är på i projektet och i webbexporten (`vram_texture_compression/for_mobile`).
  - Ljudet använder Web Audio-sampel (`audio/general/default_playback_type.web=1`) i stället för AudioWorklet-strömmar.
  - Minne: Godot 4.7:s webbmall har ingen inställning för startminnet i exporten. Minnet växer vid behov, och den mindre kortatlasen minskar toppen.
- **Krav på webbläsaren:** Godot 4.7:s mall utan trådar använder modern JavaScript (`??=`, `?.`, BigInt64Array, WebAssembly med BigInt) och kräver WebGL 2. Det motsvarar i praktiken **Safari och iOS 15 eller nyare**, men **iOS 16 eller nyare rekommenderas**, eftersom WebGL 2 i iOS 15 har fler fel. Exakt minimiversion har inte kunnat provas här, eftersom ingen WebKit finns lokalt.
- **Felruta på sidan:** webbexportens HTML (`html/head_include` i `export_presets.cfg`, källan finns i `verktyg/webbdiagnos.html`) har ett tidigt skript som fångar `window.onerror`, `unhandledrejection`, `console.error` och `console.warn`. Om spelet inte har startat efter 30 sekunder visas en röd ruta längst ned med:
  - webbläsarens user agent
  - om WebGL 2 finns
  - vilka tillägg som saknas (`EXT_color_buffer_float`, `OES_texture_float_linear` och `WEBGL_compressed_texture_*`)
  - största texturstorlek
  - Godots `Engine.getMissingFeatures()`
  - alla fel som fångats

  Rutan kan också tas fram direkt med `?diag=1` i adressen, och den stängs genom att trycka på den.

## Lägga upp onlinespelet (gratis)
Du skapar kontona själv. Inget är uppladdat härifrån.

**Servern på Render**
1. Lägg projektet i ett GitHub-repo (mappen `chicago-godot`).
2. Logga in på render.com, välj **New → Blueprint** och peka på repot. Render läser `render.yaml` och bygger `Dockerfile`. Dockerfilen laddar ned den officiella Godot 4.7.2 för Linux och kör `godot --headless -- --server --port=$PORT`.
3. När tjänsten är uppe får du en adress som `https://chicago-server-xxxx.onrender.com`. WebSocket-adressen blir då **`wss://chicago-server-xxxx.onrender.com`**.
4. Skriv in den adressen i `SERVER_PRODUKTION` i `scripts/natverk.gd` och exportera webbversionen och `.exe`-filen igen.
5. Gratisnivån somnar efter cirka 15 minuter utan trafik. Första anslutningen kan då ta upp till en minut, och bord i minnet försvinner när den somnar.

**Webbspelet på GitHub Pages (rekommenderas, då fungerar `?bord=`-länkarna)**
1. Lägg innehållet i `build/web/` i ett repo eller en `gh-pages`-gren, så att `index.html` ligger i roten.
2. Slå på Pages under **Settings → Pages**. Adressen blir `https://<användare>.github.io/<repo>/`.
3. Sätt gärna `WEBB_ADRESS` till den adressen, så att datorversionens länkar pekar dit.

**Alternativ: itch.io**
1. Zippa innehållet i `build/web/` och ladda upp det som ett HTML-spel med inställningen "This file will be played in the browser".
2. På itch körs spelet i en iframe på en annan adress, så `?bord=`-länken når inte fram. Använd **koden** och "Gå med i bord" där.

## Filer
- **Regler**
  - `scripts/motor.gd`: regelmotorn (husreglerna, den löpande totalen och redovisning efter sticket).
  - `scripts/regler.gd`: alla inställningar.
  - `scripts/handvarde.gd`, `scripts/kort.gd`: handvärdering och kortleken.
- **Grafik och gränssnitt**
  - `scripts/main.gd`: spelflödet online, handen, animeringar och kast.
  - `scripts/ui.gd`: menyer, lobby, figurväljare och HUD.
  - `scripts/bord.gd`, `scripts/kortbild.gd`, `scripts/kort3d.gd`: bordet och korten. De klädda korten läses ur `assets/kort/` (färg_valör.png).
  - `scripts/gubbe.gd`, `scripts/figurer.gd`: figurerna.
  - `scripts/ljud.gd`: ljuden.
- **Online**
  - `scripts/server.gd`: servern.
  - `scripts/klient.gd`: WebSocket-klienten.
  - `scripts/fjarrmotor.gd`: motorns gränssnitt mot servern.
  - `scripts/natverk.gd`: adresser, filtrering och protokoll.
- **Hosting**
  - `Dockerfile`, `render.yaml`, `.dockerignore`.
- **Verktyg**
  - `verktyg/rita_kort.gd`: kortleken som bild.
  - `verktyg/bellot_kladda.py`: gör de klädda korten ur [SVG-cards](https://github.com/htdebeer/SVG-cards) (`png/2x/`) till `assets/kort/`: beskär till ramlinjerna och färgar bakgrunden som kortet. Kortbild.gd lägger svenska index på en lapp över de engelska.
  - `verktyg/figurgalleri.gd`: alla figurer i en bild.
- Typsnittet är Fredoka under SIL OFL (`assets/OFL.txt`). Bilderna på de klädda korten är David Bellots SVG-cards under LGPL-2.1 (licens och upphovspersoner i `assets/kort/`, källa github.com/htdebeer/SVG-cards). Knolls lek byttes ut eftersom knektar och kungar var för lika.

## Tester
`testa.bat` kör alla fyra sviterna headless.
- `test_regler`, 433 kontroller:
  - handvärdering, bekänna färg, stick och tvåan
  - de klassiska reglerna
  - husreglerna:
    - fyrtal nollställer andra, även vid given och utan att det syns förrän efter sticket
    - poäng vid given och efter sticket, med redovisning efter sista kortet
    - köpstopp vid 41, även när det utlöses av givens poäng, och köpstoppet syns bara för spelaren själv
    - Chicago spärrat under 15, och rätten kan nås vid given
    - lyckad Chicago (+15, ingen sluthand och inga stickpoäng)
    - Theos exempel (−12)
    - givens poäng räknas även när Chicago ropas
    - Chicago en gång per parti, även efter nollställning, och tillåtet igen efter misslyckad
    - poäng efter given, byte 1 och byte 2 visas direkt, och bara stick-rundan efter sticket
    - 52 utan Chicago ger ingen vinst, en Chicago som tar spelaren över 52 vinner, och den som tagit Chicago och sedan nollställts vinner vid 52. Utan regeln vinner 52 direkt, och högst total vinner när flera når målet.
  - sparfiler
  - att en spelares vy inte innehåller andras händer, talongen eller slängda kort
- `test_figurer`: alla 14 figurer byggs och provas med alla reaktioner, kast och 6-7, och slumpade figurer blir unika.
- `test_online`: en server och tre klienter (Anna, Bo, Cia).
  - Värden kan inte starta ensam. En klient frågar om bordet (`bordinfo`), en dubblerad figur avvisas, och en icke-värd avvisas vid regeländring, start och byte till en tagen figur. Gamla robotmeddelanden (`plats`, `fyll`) avvisas.
  - Värden startar med de tre som har gått med: lediga platser tas bort, och alla behåller plats och figur.
  - Testet kontrollerar att otillåtna drag, drag i fel tur, för tidiga kast och att gå med i ett pågående parti avvisas.
  - Ett helt parti spelas, med frånkoppling (servern gör enkla drag) och återkomst via token.
  - Alla meddelanden inspekteras mot serverns facit, och ingen klient får andras kort.
  - Bordet städas bort, och servern startas också som egen process med `-- --server`.
- `test_online_scen`: hela spelet som onlineklient mot en lokal server.
  - Anna skapar bordet. Theo går med som via en delad länk: figurskärmen utan kodfält, Annas figur hoppas över, och **Gå med** leder till lobbyn med "Väntar på att Anna startar" och utan Starta-knapp.
  - Hela partiet spelas med 3D-grafiken, och i varje bildruta kontrolleras att inga dolda kort syns.
  - Anslutningen bryts mitt i, och klienten ansluter igen automatiskt och bygger upp bordet.
  - Poängen stämmer med serverns.
- Testerna spelar med en enkel spelarlogik i `tests/testspelare.gd` (den gamla robotlogiken). Den ingår inte i spelet.

## Inspelning
- `--bord=KOD`: gå med (datorversionen).
- `--server-url=ws://...`: annan server.
- `--seed=N`, `--fart=X`: frö och hastighet.

## Kvar att göra
- Servern på Render och webbspelet på GitHub Pages ska läggas upp (steg ovan), och `SERVER_PRODUKTION` ska sättas till den riktiga adressen.
- Bord ligger bara i minnet. Om servern startas om eller somnar försvinner pågående partier.
- Ingen egen avatar i hörnet. Den egna 6-7 visas i 2D.
