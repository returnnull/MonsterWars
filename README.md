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
- Hver helt har sit **eget færdighedstræ** med 19-21 evner i 7 rækker, bygget op om heltens element (atom, lyn, magma, gift, jord, frost, skygge/blod, vand, sol, skrot). Træerne har forskellig form: nogle starter fra én rod, andre fra to, og nogle har en flaskehals på midten, man skal igennem.
  - En evne kræver mindst ét point i en af de evner den hænger fra i rækken over (stregerne på skærmen).
  - **Rækkerne låses op af point brugt i hele træet**: række 2 ved 3 point, række 3 ved 7, række 4 ved 13, række 5 ved 20, række 6 ved 28 og nederste række ved 36. Én lige linje ned gennem træet koster langt mindre end det, så man er nødt til at sprede sine point for at nå bunden.
  - **Kun nogle evner kan tages flere gange** (3 eller 5 rang, vist som små firkanter på kortet). Resten læres én gang og giver så dobbelt effekt.
  - Prisen stiger ned gennem træet: 1, 2, 2, 3, 3, 4 og 5 point pr. rang.
  - Et helt træ koster 75-87 point, så med 50 point får man lidt over halvdelen og typisk 1-2 evner fra nederste række. Man skal vælge.
- Træet åbnes fra kaiju-valget med **X** (Switch) / **K**. Lær med B, nulstil alle point gratis med Y, tilbage med A. Panelet til højre viser hvad den valgte evne gør nu og hvad næste rang giver.
- Alle træer har mindst én rage-evne (mere rage, billigere rage-evner, større rage-bar, rage fra drab eller skade, Blood Pact, Wrath eller Overdrive).
- Hver helt har også en **signatur-evne** som kun den har: Gorrax *Meltdown* (atomeksplosion når rage mode starter), Voltra *Spark Gap* (chance for lyn der springer videre), Magmos *White Heat* (stærkere brand), Sylvara *Toxic Glands* (gift i 5 sekunder), Terraxa *Unbreakable* (rage mode halverer skade), Glacior *Rime Shell* (dem der rammer dig bliver bremset), Noctyr *Night Feast* (mere skade efter hvert drab), Coralis *Healing Tide* (rage-evner heler), Solar Rex *Radiance* (super-baren fyldes hurtigere) og Rustfang *Salvage* (drab reparerer dig).
- Gemte træer fra før denne ændring nulstilles én gang, så pointene kan bruges i de nye træer. XP og level beholdes.

## Rage og super

- **Rage** virker som mana. Baren fyldes når du giver skade, tager skade, vælter bygninger (og med visse evner når du besejrer fjender), og du bruger den på rage-evner. Hold **R** (tastatur **L**) og tryk en anden knap:

| Rage-evne | Knapper (Switch / tastatur) | Pris | Hvad den gør |
|---|---|---|---|
| Rage Strike | R + Y / L + J | 25 | Kaster sig frem med et hårdt slag |
| War Roar | R + B / L + mellemrum | 35 | Brøl der slår fjender tilbage og giver medspillere tæt på 15 rage |
| Rage-angreb | R + X / L + K | 50 | Heltens eget rage-angreb i dens element (se tabellen nedenfor) |
| Rage-tilstand | Tryk kort på R / L | 30+ | Kaijuen gløder, slår 30 % hårdere, er 20 % hurtigere, tager mindre skade og kan ikke slås ud af balance. Angrebene bliver til heltens eget element (se tabellen nedenfor), også med et våben i hånden: hold let angreb inde for at blive ved med at skyde heltens skud langt frem (tredje i comboen er et stort et, der sætter mærker i gaden), og hold tungt angreb inde for at lade op med glødende gab og så stå stille og puste heltens ånde frem, så længe knappen holdes (op til 4 sekunder, koster 8 ekstra rage i sekundet). Ånden gør mest skade. Bruger 10 rage i sekundet og slukkes med et nyt tryk eller når baren er tom |

  Hver helt har sine egne rage-angreb i rage-tilstand:

  | Helt | Rage-angreb (R + X) | Let (skud) | Tung (ånde) | Effekt |
  |---|---|---|---|---|
  | Gorrax | Atomic Beam: atomstråle | Atom Orb: blå kugle med elektronringe | Atomic Breath: blå atomstråle med ringe | Brænder |
  | Voltra | Lightning Storm: lyn springer fra gabet ind i fjenderne og slår ned fra himlen | Ball Lightning: knitrende kuglelyn | Thunder Breath: forgrenede lyn | Lynet springer videre til to fjender |
  | Magmos | Eruption: lavagejsere marcherer frem ad gaden | Lava Glob: lavaklump i en bue | Magma Breath: flammekaster | Brænder, efterlader glødende lava |
  | Sylvara | Venom Nova: giftbølger med giftskyer | Venom Orb: giftkugle | Toxic Mist: giftsky der bliver hængende | Gift (lang brand) og langsommere fjender |
  | Terraxa | Earthquake: krystalspyd skyder op hen ad gaden | Boulder: kampesten med krystaller | Crystal Spikes: krystalspyd skyder op af gaden | Kaster fjender op, river bygninger ned |
  | Glacior | Ice Beam: isstråle der fryser | Ice Shard: tre isspyd | Frost Breath: isnende ånde med iskrystaller | Gør langsom, ånden fryser fjender fast |
  | Noctyr | Blood Nova: bølger der suger liv | Shadow Blade: skyggesegl der skærer gennem en hel række | Soul Drain: mørk ånde der suger liv | Heler Noctyr |
  | Coralis | Torrent: vandkanon der skyller fjender væk | Bubble Blast: boble der springer | Hydro Jet: vandkanon | Skyller fjender langt tilbage |
  | Solar Rex | Sun Burst: solildsbølger | Solar Flare: lille sol | Sun Ray: gylden solstråle | Brænder |
  | Rustfang | Scrap Quake: udbrud af glødende skrot hen ad gaden | Rivet Spray: tre glødende møtrikker | Plasma Cutter: skærebrænder i en regn af gnister | River bygninger ned, gnister brænder |

  Har du ikke nok rage, blinker baren rødt. De hvide streger i baren viser, hvornår du har råd til hver evne. I rage-tilstand får du kun halvt så meget rage.
- **Rage i skilltræet.** Alle helte har evner, der ændrer hvor meget rage de får, eller hvordan de får den: mere rage fra alt, mere rage når man bliver ramt, rage for hver besejret fjende, billigere rage-evner og rage-tilstand, en større rage-bar, og grene-ender som Overdrive (rage fylder sig selv), Blood Pact (Noctyr: betal manglende rage med liv) og Tidal Fury (Coralis: halvdelen af den brugte rage fylder super-måleren).
- **Super** er en ekstra måler, der fyldes langsomt når du gør skade og besejrer fjender. Når den er fuld, trykker du **ZL** for heltens unikke super-special. Alle supers starter med en glødende runecirkel og en lyssøjle i heltens farve:

| Helt | Super-special |
|---|---|
| Gorrax | Omega Breath: kæmpe stråle hen over hele skærmen med energiringe og eksplosioner for enden |
| Voltra | Thunderstorm: en mørk tordensky, og tykke forgrenede lyn slår ned i alle fjender |
| Magmos | Magma Rain: brændende meteorer med ildhaler, der efterlader glødende lava |
| Sylvara | Singularity: et sort hul med en hvirvlende lilla skive suger fjenderne ind og eksploderer |
| Terraxa | Tectonic Rift: glødende revner og krystalspyd sprænger gaden op til begge sider |
| Glacior | Absolute Zero: frost breder sig, alle fjender fryses inde i isblokke, der knuses |
| Noctyr | Shadow Frenzy: teleporterer rundt og flår i fjenderne med røde skyggesegl |
| Coralis | Tidal Wave: en rullende vandmur med skum skyller hen over gaden |
| Solar Rex | Supernova: en sol vokser over hovedet og sender tre ringe af solild ud |
| Rustfang | Scrap Barrage: glødende skrot regner ned i gnistregn |

## Combos

Tryk knapperne i rytme, så kæder angrebene sammen. Combo-specials viser deres navn over kaijuen.

| Combo | Knapper | Hvad den gør |
|---|---|---|
| Tail Spin | let, let, let | Snurrer rundt og slår alt omkring sig væk med en chokbølge |
| Kaiju Rush | let, let, tung | Stormer frem med skulderen og ramler ind i alt på vejen, som skubbes med og får et sidste stød |
| Titan Crush | tung, tung, tung | Kæmpe dobbelt-næveslag i jorden med chokbølger, der vandrer langt frem ad gaden |
| Ground Pound | hop + tung | Styrter ned i gaden og rammer alt rundt om sig, også en svagere ring længere ude |
| Sky Claw | hop + let | Kløer opad og sender en klo-bølge skråt op, der søger mod nærmeste helikopter, drone eller fly og gør 2,5 gange skade på dem (to gange pr. hop) |

I rage-tilstand er let og tung heltens eget skud og ånde (se Rage og super).

Angreb kan ikke spammes: når en combo (eller et enkelt slag) er slut, skal kaijuen lige komme sig, før næste angreb går i gang. Efter afslutninger som Tail Spin, Titan Crush, det store rage-skud og ånden er pausen længst. Et tryk i pausen venter kort i bufferen, så rytmen holder. Rage strike, brøl og rage-angrebet har deres egen nedkøling.

Hop: kaijuen sætter af med et lille knæk i knæene, trækker benene op i toppen, strækker dem ned på vej ned og lander med et tungt dunk, støv og en chokring, der bliver større jo højere faldet er.

## Trofæer og kosmetik

Særlige bedrifter giver trofæer, og hvert trofæ låser en kosmetisk ting op, som kaijuen kan have på: én ting på hovedet, i ansigtet, om halsen, på ryggen og på halen. Gennemfører man spillet (slår slutbossen i Japan) på en sværhedsgrad, får man en kongekrone: bronze for Easy, sølv for Normal og guld for Hard. En sejr på en sværere grad giver også de lettere kroner. Derudover er der 50 andre trofæer.

- **TROPHIES** i titelmenuen viser alle 53 trofæer, hvor langt man er, og hvad de låser op.
- **Garderobe:** tryk **Y / J** (touch: STYLE) på sin kaiju i heltevalget. Op/ned vælger plads, venstre/højre skifter ting. Låste ting kan prøves på, men gemmes ikke.
- Trofæer, statistik og hvad hver kaiju har på gemmes i `user://save.json`. Gamle gemte spil får bosserne, man allerede har slået, med det samme.
- Tingene er bygget af simple former i kode (`scripts/cosmetics.gd`) og sidder fast på heltenes knogler, så de følger med, når kaijuen bevæger sig.

| Trofæ | Sådan | Kosmetik |
|---|---|---|
| Bronze Monarch | Beat the final boss on Easy (or harder) | Bronze Crown (hoved) |
| Silver Sovereign | Beat the final boss on Normal (or Hard) | Silver Crown (hoved) |
| Golden Emperor | Beat the final boss on Hard | Gold Crown (hoved) |
| Troll Toppler | Defeat HAVTROLD in Denmark | Viking Helmet (hoved) |
| Gargoyle Grinder | Defeat GARGOUILLE in France | Beret (hoved) |
| Steel Breaker | Defeat IRONCLAW in the USA | Cowboy Hat (hoved) |
| Jungle Party | Defeat JAGUARON in Brazil | Carnival Feathers (hoved) |
| Riddle Solved | Defeat SPHINXAR in Egypt | Fez (hoved) |
| Snake Charmer | Defeat NAGARAJ in India | Jewelled Turban (hoved) |
| Croc Wrangler | Defeat CROCODON in Australia | Cork Hat (hoved) |
| Mammoth Melter | Defeat MAMMOTHRAX in Russia | Ushanka (hoved) |
| Fire and Ice | Defeat SURTUR in Iceland | Wool Scarf (hals) |
| Dragon Slayer | Defeat RYUJIN PRIME in Japan | Hachimaki (hoved) |
| Pest Control | Defeat 100 enemies | Party Hat (hoved) |
| Exterminator | Defeat 1,000 enemies | Sunglasses (ansigt) |
| Extinction Event | Defeat 5,000 enemies | Gold Chain (hals) |
| Stomp Stomp | Defeat 500 infantry squads | Rubber Duck (hoved) |
| Flyswatter | Shoot down 200 aircraft | Propeller Cap (hoved) |
| Scrap Collector | Wreck 200 vehicles | Traffic Cone (hoved) |
| Monster Mash | Defeat 300 enemy monsters | Bone Necklace (hals) |
| Bomb Squad | Defeat 40 Boomticks | Lit Dynamite (hale) |
| Chopper Chopper | Shoot down 60 gunships | Toy Chopper (ryg) |
| Close Encounters | Shoot down 25 saucers | Tinfoil Hat (hoved) |
| Urban Renewal | Destroy 100 buildings | Hard Hat (hoved) |
| Wrecking Crew | Destroy 1,000 buildings | Wrecking Ball (hale) |
| Nothing Left Standing | Clear a level with 100% destruction | TNT Backpack (ryg) |
| Just Visiting | Clear a level with every building still standing | Tourist Camera (hals) |
| Warming Up | Reach a 25-hit combo | Sweatband (hoved) |
| Combo Star | Reach a 50-hit combo | Star Shades (ansigt) |
| Unstoppable | Reach a 100-hit combo | Flame Tip (hale) |
| Short Fuse | Go into rage mode 50 times | Devil Horns (hoved) |
| Loudmouth | War roar 100 times | Opera Ruff (hals) |
| Super Star | Unleash 25 super specials | Hero Cape (ryg) |
| Hot Breath | Spit 500 fireballs in rage mode | Firefighter Helmet (hoved) |
| Quarterback | Throw 100 pieces of wreckage | Coach's Whistle (hals) |
| Hoarder | Pick up 250 pieces of wreckage | Hiking Pack (ryg) |
| Can't Touch This | Dodge 500 times | Ninja Mask (ansigt) |
| Frequent Flyer | Jump 1,000 times | Jetpack (ryg) |
| Growing Up | Get a kaiju to level 10 | Graduation Cap (hoved) |
| Distinguished | Get a kaiju to level 25 | Monocle (ansigt) |
| Proud Parent | Get all 10 kaiju to level 10 | Gold Medal (hals) |
| Team Spirit | Clear a level with each of the 10 kaiju | Rainbow Scarf (hals) |
| Specialist | Learn a skill in the bottom row of a skill tree | Wizard Hat (hoved) |
| Untouchable | Clear a level without taking any damage | Halo (hoved) |
| Close Call | Clear a level with less than 10% health left | Eyepatch (ansigt) |
| Inner Peace | Defeat a boss without using any rage skill or rage mode | Prayer Beads (hals) |
| Speed Demon | Clear a level in under 75 seconds | Racing Goggles (ansigt) |
| Buddy System | Clear a level with 2 or more players | Bow Tie (hals) |
| Full House | Clear a level with 4 players | Party Balloon (hale) |
| Comeback Kid | Get knocked out 25 times | Clown Nose (ansigt) |
| Snack Time | Pick up 100 healing orbs | Lollipop (hale) |
| Millionaire | Score 1,000,000 points in total | Top Hat (hoved) |
| Hardcore | Defeat any boss on Hard | Spiked Collar (hals) |

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

Heltenes modeller ligger i `assets/heroes/` og er 10 varianter af Quaternius' T-Rex ([Poly Pizza](https://poly.pizza/m/UYtneO5FpF), CC0) med rygplader, horn, farver og proportioner, der er lavet med `tools/make_hero_variants.py` (Blender som Python-modul: `pip install bpy`). Kroppen er underopdelt til en glat model (30-70k trekanter pr. helt) med en bagt hudtekstur: farve med skæl, pletter og skygge i fordybninger, et normal map med skæl, rynker og bugriller samt ruhed/metal (`*_color.webp`, `*_normal.webp`, `*_orm.webp`, importeret som WebP for at holde webversionen lille). `SUBDIV` og `TEX` styrer detaljegrad og teksturstørrelse. Godot laver automatisk LOD-trin, så heltene tegnes med færre trekanter på afstand. Hver .glb har skelettet og animationerne Idle, Walk, Run, Attack, Jump og Death. Fjerner du `model` fra en helt i `scripts/content.gd`, bruger den igen den procedurale model.

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
scripts/rage_style.gd      Hver helts rage-angreb som data (skud, ånde, effekt, farver)
scripts/rage_fx.gd         Hvordan rage-skud, ånder og mærker i gaden ser ud
scripts/super_fx.gd        Effekterne til super-specials
scripts/fireball.gd        Rage-skuddet (flyver lige, i bue, gennem fjender eller tre ad gangen)
scripts/trophies.gd        Trofæerne, og hvordan de tælles
scripts/cosmetics.gd       De kosmetiske ting og hvor de sidder på kaijuen
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
godot --headless --path . res://tests/trophy_test.tscn   # trofæer, kroner og kosmetik
godot --headless --path . res://tests/skill_tree_test.tscn   # alle færdighedstræer følger reglerne
xvfb-run godot --path . --write-movie /tmp/lab.avi --fixed-fps 30 res://tests/anim_lab.tscn   # optag heltens animationer (gang, løb, vending, hop, angreb)
COSMETIC_IDS=gold_crown,halo godot --path . res://tests/cosmetic_shots.tscn   # billeder af tingene på kaijuerne
godot --headless --path . res://tests/hero_rage_test.tscn   # hver helts rage-angreb og super
HERO=3 godot --path . res://tests/super_shots.tscn   # billeder af en helts super (HERO=3 SHOTS=light,heavy til rage_shots.tscn)
AUTOPLAY_COSMETICS=1 godot --headless --path . res://tests/autoplay.tscn   # spil med alle ting på
godot --headless --path . res://tests/combo_test.tscn   # alle combos
godot --headless --path . res://tests/spam_test.tscn   # anti-spam og hop
xvfb-run -a godot --path . res://tests/rage_shots.tscn   # billeder af ildkugler, flammestråle og hop (SHOTS=light,heavy,jump)
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

**iPhone / iPad (og alle andre telefoner) i browseren:** spillet bygges automatisk som web-udgave og lægges på https://returnnull.github.io/MonsterWars/ hver gang der merges til main (`.github/workflows/web.yml`). Det skal slås til én gang: **Settings > Pages > Source: GitHub Actions** på GitHub. Åbn linket i Safari, vend telefonen på langs, og vælg **Del > Føj til hjemmeskærm**, så kører det i fuld skærm som en app. Web-udgaven bruger Compatibility-rendereren (WebGL 2), så skygger og effekter er lidt enklere end på pc. Spillet gemmer sig selv i browseren (offline-cache), og når en ny udgave er lagt op, skifter siden selv over til den første gang den åbnes eller genindlæses (scriptet i `html/head_include` i `export_presets.cfg`). Byg den selv med `godot --headless --path . --export-release Web export/web/index.html` og test med `python3 -m http.server -d export/web`.

**iOS som rigtig app:** kræver en Mac med Xcode og en Apple Developer-konto (99 USD/år). Udfyld *App Store Team ID* i iOS-presettet, eksporter fra Godot på Mac'en og åbn det genererede Xcode-projekt. Det kan ikke bygges fra Linux.

**Ydelse:** kaijuerne har mange polygoner (heltene 30-70k trekanter med LOD; `godot --path . res://tests/hero_perf.tscn` viser hvor mange der tegnes), så på svagere telefoner kan det blive nødvendigt at sænke `KaijuModel.detail` og antallet af fjender. Det er testet på pc med Mobile-rendereren, men endnu ikke på en rigtig telefon.

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
