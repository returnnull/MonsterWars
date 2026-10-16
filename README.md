# Kaiju Dawn

En kaiju beat 'em up i stil med *Dawn of the Monsters*, bygget i **Godot 4.4** (GDScript).
10 spilbare kaijuer, 100 baner fordelt over 10 lande, en boss i hvert land og op til 4 spillere lokalt.

Al grafik er original og genereres i kode (primitive meshes, procedurale shaders og partikler), så der er ingen ophavsretligt beskyttede assets i projektet.

## Kør spillet

1. Hent Godot 4.4 eller nyere (standard-udgaven, ikke .NET): https://godotengine.org/download
2. Åbn Godot, vælg **Import**, og peg på `project.godot` i denne mappe.
3. Tryk **F5**.

## Sådan spilles

1. **Titelskærm:** tryk B / mellemrum.
1. **Sværhedsgrad:** EASY (fjender har 70 % liv og 60 % skade), NORMAL eller HARD (140 % liv, 150 % skade, +30 % XP). Valget huskes og kan skiftes under Settings, også i pausemenuen.
2. **Vælg kaiju:** hver spiller trykker B på sin controller for at være med, vælger kaiju med venstre/højre og trykker B igen for klar. Når alle er klar, går I videre.
3. **Verdenskort:** vælg land. Et land låses op, når bossen i landet før er besejret.
4. **Banevalg:** 10 baner pr. land. Bane 10 er altid bossen. Bane 5 og 8 slutter med en elite-kaiju.
5. Efter en bane: B for næste bane (eller prøv igen), A for verdenskortet. Fremskridt, XP, færdighedspoint, holdet, bedste score og indstillinger gemmes automatisk mellem spil (`user://save.json` og `user://settings.json`; i browseren i IndexedDB). XP gemmes også efter hver bølge og når spillet lægges i baggrunden, så intet går tabt, hvis telefonen lukker appen.

Tryk **F9** i menuen for at låse alle baner op, hvis du vil teste.

## Level, evner og færdighedstræ

- Hver helt har sin egen XP og kan nå **level 25**. XP får man for hver fjende der bliver besejret (alle spillere på banen får den) og en bonus når banen er klaret. Man beholder XP selv om man taber.
- Hvert level giver **2 færdighedspoint** (50 i alt ved level 25) og lidt mere liv og skade.
- Hver helt har **10 evner** i et færdighedstræ: en rod-evne og tre grene med tre evner hver.
  - Rod: 1 point. Låser de tre grene op.
  - Trin 1: op til 5 rang, 1 point pr. rang.
  - Trin 2: op til 5 rang, 2 point pr. rang. Kræver 3 rang i trin 1.
  - Grenens ende: 6 point. Kræver at trin 2 er fyldt helt op.
- At nå enden af en gren koster mindst 19 point. Med 50 point kan man altså nå enden af to grene, men aldrig alle tre, så man skal vælge.
- Træet åbnes fra kaiju-valget med **X** (Switch) / **K**. Lær med B, nulstil alle point gratis med Y, tilbage med A.
- Evnerne er forskellige fra helt til helt og bygger på 33 effekter: mere skade, liv, fart, rage, panser, livsdræn, brand, frost, kædelyn, chokbølger fra slam, større stomp, eksplosion når man undviger, kritiske slag, ekstra skade på svækkede fjender, og grene-ender som Berserk, Second Wind (overlev et dødeligt slag), Overdrive (rage fylder sig selv), Meteor-stomp, brændende aura, skjold, nova ved combo-afslutning og livsdræn ved drab.

## Rage og super

- **Rage** virker som mana. Baren fyldes når du giver skade, tager skade, vælter bygninger (og med visse evner når du besejrer fjender), og du bruger den på rage-evner. Hold **R** (tastatur **L**) og tryk en anden knap:

| Rage-evne | Knapper (Switch / tastatur) | Pris | Hvad den gør |
|---|---|---|---|
| Rage Strike | R + Y / L + J | 25 | Kaster sig frem med et hårdt slag |
| War Roar | R + B / L + mellemrum | 35 | Brøl der slår fjender tilbage og giver medspillere tæt på 15 rage |
| Rage-angreb | R + X / L + K | 50 | Heltens Atomic Beam, Nova Burst eller Earthquake |
| Rage-tilstand | Tryk kort på R / L | 30+ | Kaijuen gløder, slår 30 % hårdere, er 20 % hurtigere, tager mindre skade og kan ikke slås ud af balance. Angrebene bliver til ild: let angreb spytter ildkugler langt frem (tredje i comboen er en stor en), og tungt angreb får kaijuen til at stå stille og sprøjte en flammestråle frem, der gør mest skade. Bruger 10 rage i sekundet og slukkes med et nyt tryk eller når baren er tom |

  Har du ikke nok rage, blinker baren rødt. De hvide streger i baren viser, hvornår du har råd til hver evne. I rage-tilstand får du kun halvt så meget rage.
- **Rage i skilltræet.** Alle helte har evner, der ændrer hvor meget rage de får, eller hvordan de får den: mere rage fra alt, mere rage når man bliver ramt, rage for hver besejret fjende, billigere rage-evner og rage-tilstand, en større rage-bar, og grene-ender som Overdrive (rage fylder sig selv), Blood Pact (Noctyr: betal manglende rage med liv) og Tidal Fury (Coralis: halvdelen af den brugte rage fylder super-måleren).
- **Super** er en ekstra måler, der fyldes langsomt når du gør skade og besejrer fjender. Når den er fuld, trykker du **ZL** for heltens unikke super-special:

| Helt | Super-special |
|---|---|
| Gorrax | Omega Breath: kæmpe stråle hen over hele skærmen |
| Voltra | Thunderstorm: lyn slår ned i alle fjender |
| Magmos | Magma Rain: meteorregn |
| Sylvara | Singularity: suger fjenderne ind og eksploderer |
| Terraxa | Tectonic Rift: jorden sprænges op til begge sider |
| Glacior | Absolute Zero: fryser alle fjender og knuser dem |
| Noctyr | Shadow Frenzy: teleporterer rundt og flår i fjenderne |
| Coralis | Tidal Wave: en flodbølge skyller hen over gaden |
| Solar Rex | Supernova: tre enorme solflammer |
| Rustfang | Scrap Barrage: regn af skrot |

## Combos

Tryk knapperne i rytme, så kæder angrebene sammen. Combo-specials viser deres navn over kaijuen.

| Combo | Knapper | Hvad den gør |
|---|---|---|
| Tail Spin | let, let, let | Snurrer rundt og slår alt omkring sig væk med en chokbølge |
| Kaiju Rush | let, let, tung | Stormer frem med skulderen og ramler ind i alt på vejen, som skubbes med og får et sidste stød |
| Titan Crush | tung, tung, tung | Kæmpe dobbelt-næveslag i jorden med chokbølger, der vandrer langt frem ad gaden |
| Ground Pound | hop + tung | Styrter ned i gaden og rammer alt rundt om sig, også en svagere ring længere ude |
| Sky Claw | hop + let | Kløer opad og sender en klo-bølge skråt op, der søger mod nærmeste helikopter, drone eller fly og gør 2,5 gange skade på dem (to gange pr. hop) |

I rage-tilstand er let og tung stadig ildkugler og flammestråle.

## Bygninger som våben

Når en bygning vælter, ligger der ofte et stykke tilbage i ruinerne med en gylden ring om. Stil dig ved det og tryk **tungt angreb** for at samle det op.

- **Stålbjælke**: lang rækkevidde. Kastet snurrer den og rammer den første fjende.
- **Betonblok**: slår hårdest. Kastet lander den med en eksplosion.
- **Antennemast**: længst rækkevidde. Kastet borer den sig gennem alle fjender på rækken.

Med våben i hånden er let angreb et sving (2-hits combo) og tungt angreb et kast. Våbnet går i stykker efter nogle slag.

## Helte

| Kaiju | Type | Rage-angreb |
|---|---|---|
| Gorrax | Allround | Atomic Beam |
| Voltra | Hurtig, lidt liv | Atomic Beam |
| Magmos | Tung og stærk | Earthquake |
| Sylvara | Hurtig | Nova Burst |
| Terraxa | Masser af liv, langsom | Earthquake |
| Glacior | Allround | Atomic Beam |
| Noctyr | Hurtigst, lidt liv | Nova Burst |
| Coralis | Allround | Atomic Beam |
| Solar Rex | Stærk | Nova Burst |
| Rustfang | Tung og stærk | Earthquake |

- **Atomic Beam:** en lang stråle fremad.
- **Nova Burst:** tre energieksplosioner rundt om dig.
- **Earthquake:** jordskælv der bevæger sig fremad langs gaden.

Heltenes modeller ligger i `assets/heroes/` og er 10 varianter af Quaternius' T-Rex ([Poly Pizza](https://poly.pizza/m/UYtneO5FpF), CC0) med rygplader, horn, farver og proportioner, der er lavet med `tools/make_hero_variants.py` (Blender som Python-modul: `pip install bpy`). Hver .glb har skelettet og animationerne Idle, Walk, Run, Attack, Jump og Death. Fjerner du `model` fra en helt i `scripts/content.gd`, bruger den igen den procedurale model.

## Lande og bosser

| # | Land | By | Stemning | Vartegn | Boss | Bossens angreb |
|---|---|---|---|---|---|---|
| 1 | Danmark | København | Overskyet, regn | Vindmøller | Havtrold | Slag, stormløb |
| 2 | Frankrig | Paris | Solnedgang | Jerntårn | Gargouille | Slag, spring |
| 3 | USA | New York | Nat | Art deco-spir | Ironclaw | Slag, stormløb, tilkalder droner |
| 4 | Brasilien | Rio | Solskin | Bjerge og statue | Jaguaron | Slag, spring, stormløb |
| 5 | Egypten | Kairo | Ørkenhede | Pyramider | Sphinxar | Slag, ild-ånde, jordslag |
| 6 | Indien | Mumbai | Diset skumring | Tempel | Nagaraj | Slag, ild-ånde, tilkalder droner |
| 7 | Australien | Sydney | Morgen | Operahuset | Crocodon | Slag, stormløb, jordslag, spring |
| 8 | Rusland | Moskva | Vinter, sne | Løgkupler | Mammothrax | Slag, jordslag, stormløb, is-ånde |
| 9 | Island | Reykjavik | Nordlys, sne | Vulkan | Surtur | Alt undtagen stormløb |
| 10 | Japan | Tokyo | Neon-nat | Radiotårn | Ryujin Prime | Alle seks angreb |

Fjender: 35 almindelige fjendetyper (se `scripts/enemies.gd`) plus en tung kamprobot som elite og en boss i hvert land. Det meste af hver bølge er militær: soldater, raketsoldater, flammekastere, mandskabsvogne, kampvogne, artilleri, missiler, helikoptere, jetfly og droner. En gang imellem kommer en svær robot (Mech Walker, Maser Cannon, Mechadon eller elite-robotten Warbot), og enkelte fjender er kaiju-monstre. Over alle 100 baner er ca. 81 % af fjenderne militær, 17 % kaiju og 2 % robotter.

Soldaterne er små ved siden af en kaiju. De holder afstand og skyder, flygter når du kommer tæt på, og flyver gennem luften når de bliver ramt. Mandskabsvognene kører frem og sætter et hold soldater af.

Kaiju-fjenderne er bygget helt anderledes end heltene (`scripts/creature_model.gd`), med seks kropstyper og hver sin kampstil:

| Kropstype | Fjender | Kampstil |
|---|---|---|
| Firbenet bæst | Mossback, Rhinox, Venomaw, Pyrodon, Shellback, Saltjaw, Titanodon | Stejler før slag, stormløb, haleslag |
| Insekt / edderkop | Skitter, Mite, Scythe, Boomtick, Scorpex, Broodmother | Zigzagger ind, bider og hopper tilbage |
| Slange / orm | Nagling, Geysirwurm, Voltwyrm | Hugger frem fra afstand, graver sig ned |
| Abe | Brawler, Gargling, Frostfang | Går på knoerne og kaster kampesten |
| Golem | Magmite | Klippekrop med glødende revner, kaster magma |
| Maskine | Mechadon, Warbot | Firbenet kampmaskine med plasmakanon og missiler |

| Land | Nye fjender | Lokal fjende |
|---|---|---|
| Danmark | Soldater, Tank, Raketsoldater, Gunship, Brawler (abe) | Mossback (mosbegroet skjoldbæst) |
| Frankrig | Mandskabsvogn (sætter soldater af), Drone, Rhinox (næsehorn) | Gargling (vinget abe) |
| USA | SAM Launcher (målsøgende missiler), Bomber Jet, Mite (sværm) | Mech Walker (robot) |
| Brasilien | Flammekastere, Scythe (mantis), Boomtick (flåt, eksploderer) | Venomaw (tudse, syre) |
| Egypten | Artillery (granater på markerede felter), Pyrodon (kraveøgle, ild) | Scorpex (skorpion) |
| Indien | Wasp Drone (kamikaze), Broodmother (edderkop) | Nagling (kobra) |
| Australien | Skitter (edderkop), Shellback (skjoldbæst) | Saltjaw (krokodille) |
| Rusland | Maser Cannon (ladet stråle), Frostfang (yeti), Titanodon (kæmpe) | |
| Island | Saucer, Geysirwurm (kæmpeorm) | Magmite (lava-golem) |
| Japan | Voltwyrm (lyn-ål) | Mechadon (kampmaskine) |

Bosserne er en blanding af kaiju, monstre og en kæmperobot. De er meget større end almindelige fjender, har en stor livsbar i bunden af skærmen, og hver boss har sit eget unikke angreb:

| Boss | Krop | Unikt angreb |
|---|---|---|
| Havtrold | Kaiju | Jordskælv: chokbølger ruller ud til begge sider |
| Gargouille | Vinget abe | Styrtdyk: flyver op og lander med en kæmpe chokbølge |
| Ironclaw | Kæmperobot | Missilsalve, og sætter soldater af |
| Jaguaron | Firbenet | Raseri: tre spring i træk |
| Sphinxar | Firbenet | Sandstorm: ånde der fejer fra højt til lavt |
| Nagaraj | Slange | Giftregn: fem giftklatter på én gang |
| Crocodon | Krokodille | Halefej hele vejen rundt (hop over den) |
| Mammothrax | Yeti | Jordskælv og kampesten |
| Surtur | Lava-golem | Meteorregn på markerede felter |
| Ryujin Prime | Kaiju | Lynstorm: tre lynnedslag efter hver spiller |

Fjenderne bliver stærkere bane for bane, og bosserne bliver større og hårdere land for land. Jordslag kan undgås ved at hoppe.

## Op til 4 spillere

- Spiller 1 bruger tastatur eller den første controller.
- Spiller 2-4 vælger kaiju i menuen eller hopper ind midt i en bane ved at trykke **B** (Switch) / **A** (Xbox) på deres egen controller.
- Alle deler én skærm. Kameraet zoomer ud når I spreder jer, og I kan højst være ca. én skærmbredde fra hinanden.
- Fjenderne får mere liv jo flere I er, og med 3-4 spillere kommer der en ekstra fjende i hver bølge.
- Bliver en spiller slået ud, kommer vedkommende tilbage med halvt liv, når bølgen er klaret. Det er først game over, når alle er nede.

## Styring

| Handling | Tastatur | Switch-controller | Xbox-controller |
|---|---|---|---|
| Bevæg (også ind/ud i dybden) | WASD / piletaster | Venstre stick / D-pad | Venstre stick / D-pad |
| Hop | Mellemrum | B | A |
| Let angreb (3-hits combo) | J | Y | X |
| Tungt angreb (slam) | K | X | Y |
| Angreb i luften = stomp | J/K i luften | Y/X i luften | X/Y i luften |
| Undvig (usårlig kort tid) | Shift | A eller L | B eller LB |
| Rage-tilstand, og så rage-angreb | L | R eller ZR | RB eller RT |
| Super-special (når SUPER er fuld) | U | ZL | LT |
| Saml bygningsstykke op / kast det | K ved stykket | X ved stykket | Y ved stykket |
| Pause | Esc / Enter | + | Start |

Knapperne er mappet efter position, så de sidder rigtigt på en Switch Pro Controller og Joy-Cons.

På mobil og tablet styrer spiller 1 med touch: venstre halvdel af skærmen er en stick der dukker op, hvor tommelfingeren rammer, og til højre sidder JUMP, LIGHT, HEAVY og DODGE (samme placering som på Switch) plus RAGE, SUPER og pause. Hold RAGE med én finger og tryk LIGHT/JUMP/HEAVY med en anden for rage-angreb. I menuerne skifter knapperne: kun de knapper, der gør noget på skærmen, vises, og de hedder det, de gør (grøn **OK** til at vælge, rød **BACK** til at gå tilbage, plus fx SKILLS, LEARN, RESET og PLAY). Hjælpeteksten nederst følger med. Tilslutter man en controller, forsvinder touch-knapperne og kommer igen ved næste berøring, og spiller 2-4 kan stadig hoppe ind på egne controllere.

Alle gamepads som Godot kender virker (Switch Pro, Joy-Con par, Xbox, PlayStation og de fleste andre). Controller 1 er spiller 1 sammen med tastaturet, controller 2 er spiller 2 og så videre. Controllerne rumler når du bliver ramt, slår hårdt, går i rage og bruger super. Hvis en controller mister forbindelsen midt i en bane, pauses spillet.

## Hvad er med

- **Gorrax**, den spilbare kaiju: let combo der ender i en hale-spin, tungt slam med chokbølge, stomp fra luften, undvigelse med i-frames og et atom-beam der lades op af rage.
- **Rage**: optjenes ved at ramme fjender, tage skade og vælte bygninger. Når baren er fuld, gløder rygpladerne.
- **Destruerbar by**: bygninger tager skade (vinduer slukker, sod breder sig), kollapser ned i gaden med murbrokker, støv og eksplosioner, og giver point, rage og sommetider en grøn helbredelses-orb.
- **Fjender**: Brute-kaijuer (nærkamp med tydelig opladning), militærdroner (skyder plasma og dykker ned så du kan ramme dem), og bossen Tyrannox, der er større, tåler lette slag og laver stormløb.
- **Juice**: hitstop, skærmrystelse, gnister, lys-blink, combo-tæller, destruktions-procent.
- **Grafik**: Forward+ med skygger, SSAO, skærmrefleksioner på våd asfalt, glow, tåge og solnedgangshimmel, skæl-normal-map på kaijuerne og procedural vindues-shader på bygningerne.

## Projektstruktur

```
project.godot              Indstillinger, renderer, autoload
scenes/menu.tscn           Startscene: titel, heltevalg, verdenskort, banevalg
scenes/main.tscn           En bane (bygges i kode ud fra Game.level)
scripts/menu.gd            Menuerne
scripts/autoload/touch_controls.gd  Touch-knapper til mobil (fodrer de samme input actions som en controller)
scripts/content.gd         Alt indhold som data: helte, lande, bosser, banegenerator
scripts/stage_builder.gd   Bygger et lands bane: lys, vejr, by, skyline, vartegn
scripts/skills.gd          Færdighedstræer, evner, XP-kurve og super-specials
scripts/weapon.gd          Bygningsstykker der kan samles op og kastes
scripts/main.gd            Bølger, spillere, XP og win/lose for en bane
scripts/autoload/game.gd   Global tilstand, point, hitstop, input-mapping
scripts/kaiju.gd           Fælles krop for kaijuer: liv, knockback, strike()
scripts/player.gd          Spillerens kaiju og angreb
scripts/brute.gd           Fjende-kaijuer (crawler, brute, elite) og bosser
scripts/flyer.gd           Drone-fjende
scripts/sky_wave.gd        Klo-bølgen fra Sky Claw (hop + let)
scripts/projectile.gd      Plasma-skud
scripts/building.gd        Destruerbare bygninger
scripts/kaiju_model.gd     Procedural kaiju-model og animation
scripts/glb_kaiju_model.gd Heltemodel fra .glb (assets/heroes) styret af samme pose-mål
assets/heroes/             De 10 T-Rex-varianter (CC0, Quaternius)
tools/make_hero_variants.py  Blender-script der laver T-Rex-varianterne
scripts/camera_rig.gd      Kamera med look-ahead og shake
scripts/hud.gd             HUD, pause og slutskærm
scripts/fx.gd              Partikler, lysglimt og chokbølger
shaders/building.gdshader  Vinduer, lys og skade på bygninger
tests/autoplay.tscn        Udvikler-test der spiller banen automatisk
```

Kør den automatiske test (spiller bane 1-10 med bossen og afslutter):

```
godot --headless --path . res://tests/autoplay.tscn
AUTOPLAY_PLAYERS=4 godot --headless --path . res://tests/autoplay.tscn
AUTOPLAY_LEVELS=bosses godot --headless --path . res://tests/autoplay.tscn   # alle 10 bosser
AUTOPLAY_LEVELS=all AUTOPLAY_SECONDS=0 godot --headless --path . res://tests/autoplay.tscn   # byg alle 100 baner
AUTOPLAY_SKILLS=1 AUTOPLAY_SUPER=1 godot --headless --path . res://tests/autoplay.tscn   # alle evner og supers i brug
KAIJU_TOUCH=1 godot --headless --path . res://tests/touch_test.tscn   # touch-knapperne
godot --headless --path . res://tests/difficulty_test.tscn   # sværhedsgraderne
godot --headless --path . res://tests/combo_test.tscn   # alle combos
```

## Mobil (Android / iOS)

Spillet kan bygges til Android og iOS. `export_presets.cfg` har færdige presets til begge, og på telefonen kører det automatisk med Mobile-rendereren, 2048-skygger og touch-knapper.

**Prøv touch-styringen på pc:** `KAIJU_TOUCH=1 godot --path .` (musen virker som en finger).

**Android-build på Linux:**

1. Installer Java 17 og Android SDK, f.eks. på Ubuntu/Debian:
   ```
   sudo apt install openjdk-17-jdk
   mkdir -p ~/android-sdk/cmdline-tools && cd ~/android-sdk
   wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
   unzip commandlinetools-linux-*.zip -d cmdline-tools && mv cmdline-tools/cmdline-tools cmdline-tools/latest
   cmdline-tools/latest/bin/sdkmanager --sdk_root=$HOME/android-sdk "platform-tools" "build-tools;34.0.0" "platforms;android-34"
   ```
2. Lav en debug-nøgle (kun én gang):
   ```
   keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore ~/debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
   ```
3. I Godot: **Editor > Editor Settings > Export > Android**: sæt *Android SDK Path* til `~/android-sdk`, *Java SDK Path* til `/usr/lib/jvm/java-17-openjdk-amd64` og *Debug Keystore* til `~/debug.keystore` (bruger `androiddebugkey` / `android`).
4. **Editor > Manage Export Templates > Download and Install**.
5. Sæt telefonen i udviklertilstand med USB-fejlfinding, sæt den i, og tryk på Android-ikonet øverst til højre i Godot for at køre spillet direkte på den. Eller byg en APK med **Project > Export > Android** (eller `godot --headless --path . --export-debug Android export/android/kaiju-dawn.apk`) og installer med `adb install export/android/kaiju-dawn.apk`.

Til Google Play skal man bruge en release-nøgle i stedet for debug-nøglen og eksportere som AAB (slå *Gradle Build* til i presettet).

**iPhone / iPad (og alle andre telefoner) i browseren:** spillet bygges automatisk som web-udgave og lægges på https://returnnull.github.io/MonsterWars/ hver gang der merges til main (`.github/workflows/web.yml`). Det skal slås til én gang: **Settings > Pages > Source: GitHub Actions** på GitHub. Åbn linket i Safari, vend telefonen på langs, og vælg **Del > Føj til hjemmeskærm**, så kører det i fuld skærm som en app. Web-udgaven bruger Compatibility-rendereren (WebGL 2), så skygger og effekter er lidt enklere end på pc. Byg den selv med `godot --headless --path . --export-release Web export/web/index.html` og test med `python3 -m http.server -d export/web`.

**iOS som rigtig app:** kræver en Mac med Xcode og en Apple Developer-konto (99 USD/år). Udfyld *App Store Team ID* i iOS-presettet, eksporter fra Godot på Mac'en og åbn det genererede Xcode-projekt. Det kan ikke bygges fra Linux.

**Ydelse:** kaijuerne har mange polygoner (helte ca. 200k trekanter), så på svagere telefoner kan det blive nødvendigt at sænke `KaijuModel.detail` og antallet af fjender. Det er testet på pc med Mobile-rendereren, men endnu ikke på en rigtig telefon.

## Nintendo Switch

Godot kan ikke eksportere direkte til Switch fra den almindelige udgave. For at udgive på Switch skal man:

1. Være godkendt udvikler hos Nintendo (Nintendo Developer Portal) og have et devkit.
2. Bruge en licenseret Switch-port af Godot, f.eks. W4 Games (W4 Consoles) eller et porting-firma som Lone Wolf Technology eller Pineapple Works.

Projektet er forberedt til det:

- Input er mappet positionsbaseret til gamepad, og alt kan styres uden mus.
- `rendering_method.mobile` er sat til Mobile-rendereren, som er den man typisk bruger på Switch. Forward+-effekterne (SSR, SSAO) skal slås fra eller ned på Switch, og skyggeopløsningen bør sænkes til 2048.
- UI er lavet til 1920x1080 og skalerer ned til 1280x720 i håndholdt tilstand.
- Al geometri er simple meshes med få draw calls; byens baggrund deler materialer.

## Næste skridt

- Rigtige modeller og animationer (f.eks. lavet i Blender) i stedet for de procedurale kaijuer.
- Lyd og musik.
- Greb og kast, unikke angreb pr. helt og en historie-mode mellem landene.
- Mulighed for at spille med én Joy-Con pr. spiller (sidelæns).
