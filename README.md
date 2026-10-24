# Chicago (Godot 4.7: dator, webb och online)

Svensk Chicago, pokervarianten med byten och stick, vid ett 3D-kortbord med tecknade figurer på platserna. Man kan spela mot robotar, turas om vid samma dator eller spela online med vänner via en delbar länk. Det går bara om poäng, utan insatser. Allt byggs i kod: kortleken, bordet, figurerna, ljuset och ljuden.

- **Spela:** `spela.bat` · **Editorn:** `redigera.bat` · **Tester:** `testa.bat`
- **Färdiga byggen:** `build/windows/Chicago.exe` (en fil) och `build/web/` (webbversionen).
- **Styrning:** klicka på kort för att välja vilka som ska bytas och tryck **Byt**. I sticken klickar du på kortet du vill spela, och otillåtna kort är mörkare. Tangenterna 1–5 väljer kort, Enter bekräftar och Esc pausar.
- **Kasta och hälsa:** klicka på en annan spelares figur eller namn. Knappen **6-7** uppe till höger gör 6-7 själv.

## Theos husregler (standard)
Allt går att ändra under **Nytt parti** eller **Skapa bord online**. Knappen **Klassiska regler** ger de vanligaste svenska reglerna i stället.

| Regel | Standard |
|---|---|
| Målpoäng | 52 (avgörs när rundans poäng redovisas) |
| Poängtabell | par 1, två par 2, triss 3, stege 4, färg 5, kåk 6, **fyrtal 8**, **färgstege 10**, royal straight flush 52 |
| Fyrtal | **nollställer alla andra spelares totalpoäng** (inställning, på) |
| När händerna poängsätts | **givens hand** (de utdelade korten innan något byte) och **handen man spelade sticket med**, efter sticket. Inga poäng efter bytena. Den äldre varianten med poäng efter varje byte finns kvar som inställning. |
| Visning | rundans poäng (givens hand, sluthand, stick, Chicago) **visas och läggs till totalen först när sticket är klart** |
| Bara bästa handen | bara den bästa handen vid bordet får poäng, och högt kort ger inget. Vid exakt lika får den som är först i tur efter given poängen. |
| Köpstopp | den som har **41 poäng eller mer** får inte byta och står över bytena (inställbart) |
| Byten | 3 omgångar, 0–5 kort |
| Sista sticket | 2 poäng, eller **5 poäng om det tas med en tvåa** (två egna värden, ingen faktor) |
| Chicago | får bara ropas med **minst 15 poäng**. Lyckas det ger det **+15**, och inga stickpoäng eller handpoäng efter sticket delas ut. Spricker det blir det **−15**, men spelarens stick- och handpoäng efter sticket räknas ändå. Theos exempel: −15 + sista sticket 2 + par 1 = **−12**. Givens poäng räknas alltid. |
| Chicago en gång per parti | den som har **lyckats** får inte ropa igen, inte ens efter att ha blivit nollställd av ett fyrtal. En misslyckad Chicago förbrukar inte rätten. Den som har tagit sin Chicago märks med "Chicago tagen" i poängtavlan. |

**Avgörande om totalen:** köpstoppet (41), kravet för Chicago (15) och fyrtalets nollställning räknas på en **löpande intern total**. Den innehåller poängen från givens hand i den pågående rundan. Det var Theos svar. Den som når 41 genom givens poäng får alltså inte byta i samma runda, och den som når 15 vid given får ropa Chicago. Ett fyrtal vid given nollställer de andra direkt, vilket påverkar deras köpstopp och Chicago-rätt. Skärmen följer ändå regeln att poängen visas efter sticket.

**Eget val:** färgstege har 10 poäng som standard, så att den är värd mer än fyrtalet (8). Det är också värdet i Theos första poängtabell.

## Dolda kort
- Det enda som syns öppet är **kortet en spelare lägger i sticket** och **den egna handen för den människa som har turen**. Mot robotar är det den enda människans hand.
- **Vid poängsättningen vänds inga kort.** Spelet säger bara till exempel "Anna: färg, 5 poäng", aldrig färger eller valörer. Lika händer avgörs i hemlighet.
- Robotarnas händer, slängda kort, talongen och tagna stick ligger alltid med baksidan upp.
- Under Chicago-frågan visas inte vems tur det är, eftersom det skulle avslöja vem som har rätt att ropa. Köpstopp och Chicago-rätt får man bara veta om sig själv. För andra syns bara att de "står över".
- Vid flera människor på samma dator visas skärmen **"Lämna över till <namn>"** mellan turerna, och handen vänds först när nästa spelare klickar.
- Robotarna och onlineklienterna får bara spelarens egen vy (`motor.vy(p)`). Ingen kan fuska.
- Undantaget är demoläget med fyra robotar, där korten får synas.

## Figurer, kast och 6-7
- **14 figurer** (`scripts/figurer.gd`, byggs av `scripts/gubbe.gd`). De skiljer sig i:
  - kroppsform: smal, rund, lång, kort
  - hudton
  - frisyr och hårfärg
  - ögon, mun och ögonbryn
  - kläder: tröja, kavaj, hoodie, randig, kockrock, väst
  - accessoarer: hatt, keps, glasögon, solglasögon, skägg, mustasch, hörlurar, fluga, mössa, krona, piratlapp, kockmössa, cowboyhatt

  Extrafigurerna är **Robot R7, Kapten Jack (pirat), Kocken, Cowboy-Kalle, Hunden Doris och Katten Måns**.
- Varje plats väljer figur i **Nytt parti** med en snurrande förhandsvisning och knapparna Föregående och Nästa. Online väljer man i lobbyn. Robotar och "slumpad" får en figur som inte redan är vald. Theos val sparas i `user://chicago.cfg`, och online skickas valet via servern.
- Figurerna andas, tittar mot den som har turen, gestikulerar när de spelar, jublar vid poäng och sitter bakom bordskanten så att de inte skymmer korten.
- **Kastmenyn**
  - Kasta: vattenballong, tomat, gräddtårta, snöboll, pappersflygplan.
  - Hälsa: ros, fingerkyss, krona, konfetti, 6-7.

  Det finns 3 sekunders spärrtid. Robotar kastar ibland tillbaka och gör ibland 6-7 när de tar ett stick eller poäng. Det stängs av med kryssrutan "Robotar kastar tillbaka och busar".
- **6-7:** figuren håller båda handflatorna uppåt och gungar händerna i otakt med en pratbubbla och ett syntetiserat ljud. Inget av detta påverkar spelet eller visar kort.

## Spela online
1. **Skapa bord online …**: skriv ditt namn, välj antal platser, regler och figur, och tryck **Skapa bord**. Du får en kod (till exempel `K7Q2`) och en lobby.
2. **Kopiera länk** och skicka den. Kompisarna öppnar `https://<din-sida>/?bord=K7Q2`, och spelet går direkt till "Gå med" med koden ifylld. De kan också välja **Gå med i bord …** och skriva koden.
3. I lobbyn syns platserna, figurerna och partiets regler. Värden kan lägga robotar (lätt, medel eller svår) på tomma platser eller trycka **Fyll tomma platser med robotar**, och sedan **Starta**.
4. Tappar någon anslutningen ansluter klienten själv igen med en token som är sparad lokalt (`user://chicago_online.cfg`). Samma länk fungerar också. Medan spelaren är borta gör en robot dragen efter 6 sekunder.
5. Bord utan anslutna människor städas bort efter 10 minuter.

Servern (`scripts/server.gd`) är auktoritativ med `motor.gd` som enda sanning. Den blandar, ger, avgör stick och poäng och låter robotar spela. Varje klient får bara sin egen hand och det offentliga. Andras kort skickas aldrig: i givar och byten kommer de som `-1` (`scripts/natverk.gd`, `filtrera`/`tillstand`). Klienten visar dem med anonyma kortnoder som byter identitet osynligt när ett kort spelas ut. Allt valideras på servern: otillåtna drag, drag i fel tur, för tidiga kast, start av någon annan än värden och att gå med i ett pågående parti utan token. Protokollet är JSON över WebSocket.

**Serveradress:** den sätts i `scripts/natverk.gd`.
- `SERVER_LOKAL` (`ws://localhost:9080`) används när spelet körs från editorn och när webbsidan körs över http, till exempel lokalt.
- `SERVER_PRODUKTION` (`wss://chicago-server.onrender.com`) används när webbsidan körs över https och i den exporterade `.exe`-filen. **Ändra den till din Render-adress innan du exporterar.**
- På webben kan adressen också ges med `?server=wss://...` i länken. I datorversionen går det med `-- --server-url=...`.
- `WEBB_ADRESS` är adressen till webbspelet, och den används för länken som datorversionen kopierar. På webben används sidans egen adress.

Lokal server: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -- --server --port=9080`. Porten kan också sättas med miljövariabeln `PORT`.

## Webbversion
- Exportprofilen **Web** körs utan trådar (nothreads) till `build/web/`, och **Windows** exporteras till `build/windows/Chicago.exe`. Båda finns i `export_presets.cfg`.
- Webben använder renderaren **Compatibility** via en webböverstyrning (`rendering_method.web`). Datorversionen behåller Forward+.
- Webben börjar med skärmen **"Klicka för att börja"**, eftersom ljud kräver ett klick. Avsluta-knappen är dold.
- Exportera igen: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-release "Web" build/web/index.html`.
- Prova lokalt: `py -m http.server 8060 --directory build/web` och öppna `http://localhost:8060/`. Starta också den lokala servern för att spela online.
- **Skillnader i Compatibility** (`bord.gd` och andra skript):
  - **Skuggorna från lampan är avstängda**, eftersom de blev helt svarta.
  - **SSAO** och **mjuka skuggor** (`light_size`, `shadow_blur`) finns inte.
  - Glow är enklare.
  - Färgjustering, ACES, clearcoat och normalkartor fungerade i provet.
  - `instance uniform` (kortglöden) fungerar.
  - MSAA och `ALPHA_TO_COVERAGE` är begränsade i WebGL, så korthörnen blir lite skarpare.

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

## Robotar
- **Lätt:** tumregler och ibland misstag.
- **Medel:** provar alla 32 sätt att behålla kort mot kort den inte har sett, och sparar höga kort till sista sticket.
- **Svår:** som medel, men väger handen efter chansen att vara bäst, och simulerar sticken mot slumpade fördelningar av okända kort.
- Robotarna följer husreglerna: de byter inte vid köpstopp, ropar Chicago bara när de får (minst 15 och inte redan tagen) och kan inte se andras kort.

## Filer
- **Regler och robotar**
  - `scripts/motor.gd`: regelmotorn (husreglerna, den löpande totalen och redovisning efter sticket).
  - `scripts/regler.gd`: alla inställningar.
  - `scripts/handvarde.gd`, `scripts/kort.gd`: handvärdering och kortleken.
  - `scripts/robot.gd`: robotarna.
- **Grafik och gränssnitt**
  - `scripts/main.gd`: spelflödet lokalt och online, animeringar och kast.
  - `scripts/ui.gd`: menyer, lobby, figurväljare och HUD.
  - `scripts/bord.gd`, `scripts/kortbild.gd`, `scripts/kort3d.gd`: bordet och korten.
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
  - `verktyg/figurgalleri.gd`: alla figurer i en bild.
- Typsnittet är Fredoka under SIL OFL (`assets/OFL.txt`).

## Tester
`testa.bat` kör alla sju sviterna headless.
- `test_regler`, 416 kontroller:
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
    - robotar följer reglerna
  - sparfiler
  - att robotarna inte fuskar
- `test_robotar`: 28 hela partier med 2–6 spelare och olika regler, plus nivåjämförelse.
- `test_figurer`: alla 14 figurer byggs och provas med alla reaktioner, kast och 6-7, och slumpade figurer blir unika.
- `test_dolda_kort`: 3D-scenen, både mot robotar och med två människor på samma dator, med alla kast igång. Testet kontrollerar i varje bildruta att inga otillåtna kort syns.
- `test_scen`: ett helt robotparti i 3D, där alla tio kast och hälsningar och den egna 6-7 provas.
- `test_online`: en server och tre klienter.
  - De skapar ett bord, går med via kod och lägger till en robot.
  - Testet kontrollerar figurerna och att otillåtna drag, drag i fel tur, för tidiga kast, fel startare och att gå med i ett pågående parti avvisas.
  - Ett helt parti spelas, med frånkoppling och återkomst via token.
  - Alla cirka 800 meddelanden inspekteras mot serverns facit, och ingen klient får andras kort.
  - Bordet städas bort.
  - Servern startas också som egen process med `-- --server`.
- `test_online_scen`: hela spelet som onlineklient mot en lokal server, med en gäst och en robot.
  - Hela partiet spelas med 3D-grafiken, och det kontrolleras att inga dolda kort syns.
  - Anslutningen bryts mitt i, och klienten ansluter igen automatiskt och bygger upp bordet.
  - Poängen stämmer med serverns.
- Webben provades i Chrome headless med Puppeteer (utanför projektet): startskärmen, menyn, `?bord=KOD`, gå med, lobbyn och spelet mot en lokal server, utan konsolfel.

## Demo och inspelning
```
Godot_v4.7.2-stable_win64_console.exe --path . --position 4000,4000 --write-movie ut/f.png --fixed-fps 10 --quit-after 600 -- --demo --seed=3
```
- `--demo`: fyra robotar med öppna kort.
- `--automan`: du-perspektivet, där en automatisk "människa" spelar.
- `--hotseat`: två människor på samma dator.
- `--kasta`: kastar alla sorter i tur och ordning.
- `--kastmeny`: öppnar kastmenyn.
- `--seed=N`, `--fart=X`, `--mal=N`: frö, hastighet och målpoäng.
- `--installningar`, `--figurval`, `--regler`, `--lobbydemo`: öppnar skärmarna direkt.
- `--bord=KOD`: gå med (datorversionen).
- `--server-url=ws://...`: annan server.

## Kvar att göra
- Servern på Render och webbspelet på GitHub Pages ska läggas upp (steg ovan), och `SERVER_PRODUKTION` ska sättas till den riktiga adressen.
- Bord ligger bara i minnet. Om servern startas om eller somnar försvinner pågående partier.
- Ingen egen avatar i hörnet. Den egna 6-7 visas i 2D.
- Robotarna drar ingen slutsats av hur många kort andra byter.
