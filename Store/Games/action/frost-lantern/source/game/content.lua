local C={lang=1}
function C.t(value) if type(value)=="table" then return value[C.lang] or value[1] end return tostring(value) end
C.biomes={
 {name={"Yosun Mahzeni","Moss Crypt"},boss={"Diken Tacı","The Thorn Crown"},story={"Fenerin ilk kıvılcımı köklerin altında saklı. Mahzenin bekçisi eski ışığı geri vermiyor.","The lantern's first spark sleeps beneath the roots. The keeper will not surrender its light."},color="#69cdb5"},
 {name={"Kızıl Dökümhane","Crimson Foundry"},boss={"Cüruf Kalbi","The Cinder Heart"},story={"Demir nehirler durmuş, ocak hâlâ canlı. Küllerin arasında ikinci kıvılcımı ara.","The iron rivers have stopped, but the furnace lives. Find the second spark among the ashes."},color="#f6a166"},
 {name={"Donmuş Manastır","Frozen Monastery"},boss={"Çanların Dul'u","The Bell Widow"},story={"Burada çanlar ses değil hatıra taşır. Donmuş avlunun sessizliğini boz.","These bells carry memories instead of sound. Break the silence of the frozen courtyard."},color="#a2dfe7"},
 {name={"Rüya Bahçesi","Dream Garden"},boss={"Spor Ana","The Spore Mother"},story={"Bahçedeki çiçekler rüya görüyor. Onları uyandıran zehri kökünden sök.","The flowers are dreaming. Uproot the poison that keeps them asleep."},color="#dc9ecb"},
 {name={"Yıldız Arşivi","Astral Archive"},boss={"Son Müneccim","The Last Astrologer"},story={"Beş kıvılcım aynı göğe ait. Kaybolan şafağı arşivin son sayfasından kurtar.","Five sparks belong to the same sky. Rescue the lost dawn from the archive's final page."},color="#b8adf1"}
}
C.weapons={
 {name={"Fener Kılıcı","Lantern Blade"},desc={"Geniş yay · seri yakın dövüş","Wide arc · quick melee"},damage=17,cool=.35,reach=55},
 {name={"Bakır Arbalet","Copper Crossbow"},desc={"Uzun menzil · delici ok","Long range · piercing bolts"},damage=22,cool=.62,reach=300},
 {name={"Ayaz Asası","Frost Staff"},desc={"Hızlı büyü · yavaşlatan öz","Rapid magic · chilling essence"},damage=11,cool=.27,reach=250}
}
C.enemies={{"Kök Nöbetçisi","Root Guard"},{"Cürufçu","Cinder Walker"},{"Ayaz Ruhu","Frost Wisp"},{"Spor Cadısı","Spore Witch"},{"Yıldız Gözcüsü","Star Sentinel"},{"Boynuzlu Avcı","Antler Hunter"},{"Ocak Topçusu","Furnace Gunner"},{"Çan Hayaleti","Bell Phantom"},{"Mantar Şövalyesi","Mycelium Knight"},{"Arşiv Kâtibi","Archive Scribe"}}
-- Every boon has a functional stat or proc. Rank caps keep three-card rewards valid.
C.boons={
 {id="edge",name={"Bilenmiş Bakır","Honed Copper"},desc={"Silah hasarı +%18.","Weapon damage +18%."},icon=2,max=5,rarity=1},
 {id="haste",name={"Çabuk Eller","Quick Hands"},desc={"Saldırı beklemesi -%10.","Attack cooldown -10%."},icon=4,max=4,rarity=1},
 {id="vital",name={"Kök Zırhı","Root Armour"},desc={"Azami can +15; 15 can yenile.","Maximum health +15; heal 15."},icon=5,max=4,rarity=1},
 {id="stride",name={"Rüzgâr Adımı","Wind Step"},desc={"Hareket hızı +%10.","Movement speed +10%."},icon=4,max=3,rarity=1},
 {id="ember",name={"Köz Mührü","Ember Seal"},desc={"Vuruşlar 3 sn boyunca yakar.","Hits burn enemies for 3 seconds."},icon=1,max=3,rarity=1},
 {id="frost",name={"Ayaz İpliği","Frost Thread"},desc={"Vuruşlar düşmanı yavaşlatır.","Hits slow enemies."},icon=8,max=3,rarity=1},
 {id="venom",name={"Spor Zehri","Spore Venom"},desc={"Vuruşlar biriken zehir uygular.","Hits apply stacking poison."},icon=9,max=3,rarity=1},
 {id="spark",name={"Çatallı Şimşek","Forked Lightning"},desc={"Her 4. isabet yakına yıldırım saçar.","Every fourth hit arcs to nearby foes."},icon=12,max=3,rarity=2},
 {id="bleed",name={"Kesik Ay","Crescent Cut"},desc={"Vuruşlar 4 sn kanama uygular.","Hits inflict bleeding for 4 seconds."},icon=10,max=3,rarity=1},
 {id="leech",name={"Aç Fener","Hungry Lantern"},desc={"Her 5 öldürmede 5 can kazan.","Every 5 kills restore 5 health."},icon=13,max=3,rarity=2},
 {id="guard",name={"Bakır Tüy","Copper Feather"},desc={"Alınan hasar -%8.","Incoming damage -8%."},icon=3,max=4,rarity=1},
 {id="flask",name={"Şifacı Şişesi","Healer's Flask"},desc={"Bir iksir kazan; şifa miktarı +10.","Gain a potion; potion healing +10."},icon=7,max=3,rarity=1},
 {id="orbit",name={"Uydu Fener","Orbit Lantern"},desc={"Etrafında dönen hasar veren bir ışık.","An orbiting light damages enemies."},icon=6,max=3,rarity=2},
 {id="dashfire",name={"Köz İzi","Ember Trail"},desc={"Atılınca patlayan bir köz bırak.","Dashing leaves an explosive ember."},icon=17,max=3,rarity=2},
 {id="echo",name={"Yankı Oku","Echo Bolt"},desc={"Mermili silahlar fazladan atış yapar.","Ranged weapons fire an extra shot."},icon=18,max=2,rarity=2},
 {id="pierce",name={"Cam Uç","Glass Tip"},desc={"Atışlar bir düşmanı daha deler.","Projectiles pierce one extra enemy."},icon=24,max=3,rarity=1},
 {id="crit",name={"Keskin Bakış","Keen Sight"},desc={"Kritik vuruş ihtimali +%8.","Critical strike chance +8%."},icon=22,max=4,rarity=1},
 {id="fortune",name={"Altın Yosun","Golden Moss"},desc={"Düşmanlardan gelen altın +%25.","Gold from enemies +25%."},icon=32,max=3,rarity=1},
 {id="nova",name={"Şafak Patlaması","Dawn Nova"},desc={"Fener yeteneği hasarı +%30.","Lantern ability damage +30%."},icon=20,max=3,rarity=2},
 {id="focus",name={"Derin Nefes","Deep Breath"},desc={"Fener yeteneği beklemesi -2 sn.","Lantern ability cooldown -2 seconds."},icon=21,max=3,rarity=1},
 {id="thorns",name={"Diken Borcu","Thorn Debt"},desc={"Hasar alınca yakındakilere 15 vur.","Taking damage deals 15 nearby."},icon=25,max=3,rarity=1},
 {id="execute",name={"Son Kıvılcım","Final Spark"},desc={"Canı az düşmana +%30 hasar.","Deal +30% damage to wounded foes."},icon=26,max=3,rarity=2},
 {id="shield",name={"Sessiz Hale","Quiet Halo"},desc={"Her oda başında bir darbeyi engelle.","Block one hit at each room's start."},icon=27,max=1,rarity=3},
 {id="magnet",name={"Çağıran Taş","Calling Stone"},desc={"Ganimet çekim alanı +45 piksel.","Loot attraction radius +45 pixels."},icon=30,max=3,rarity=1},
 {id="blast",name={"Çatlak Çekirdek","Cracked Core"},desc={"Ölen düşman küçük patlama bırakır.","Defeated foes leave a small blast."},icon=33,max=2,rarity=2},
 {id="renew",name={"İlkbahar Andı","Spring Oath"},desc={"Her temizlenen odada 4 can yenile.","Heal 4 after clearing each room."},icon=29,max=3,rarity=1},
 {id="glass",name={"Cam Yemin","Glass Oath"},desc={"+%35 hasar; +%15 alınan hasar.","+35% damage; +15% incoming damage."},icon=40,max=2,rarity=3},
 {id="dash",name={"İkinci Nefes","Second Wind"},desc={"Atılma beklemesi -%20.","Dash cooldown -20%."},icon=28,max=3,rarity=1},
 {id="resolve",name={"Son Sığınak","Last Shelter"},desc={"Can %30 altındayken +%25 hasar.","+25% damage below 30% health."},icon=35,max=2,rarity=2},
 {id="relic",name={"Şafak Kalıntısı","Dawn Relic"},desc={"+%12 hasar, +10 can, bir iksir.","+12% damage, +10 health, one potion."},icon=38,max=5,rarity=3}
}
C.byId={};for _,b in ipairs(C.boons) do C.byId[b.id]=b end
C.synergies={
 {a="ember",b="frost",name={"TERMAL ŞOK","THERMAL SHOCK"},desc={"Yanan hedefi dondurmak ek hasar verir.","Chilling a burning target deals bonus damage."}},
 {a="venom",b="blast",name={"SPOR ZİNCİRİ","SPORE CHAIN"},desc={"Ölüm patlamaları zehir yayar.","Death explosions spread poison."}},
 {a="spark",b="orbit",name={"YILDIZ ÇEMBERİ","STAR RING"},desc={"Uydu ışıkları da yıldırım tetikler.","Orbiting lights can trigger lightning."}},
 {a="bleed",b="execute",name={"KIZIL HÜKÜM","CRIMSON VERDICT"},desc={"Kanayan hedeflere bitirici hasar artar.","Execute damage increases against bleeding foes."}},
 {a="dashfire",b="ember",name={"KÜL ADIMI","ASHEN STEP"},desc={"Atılma patlaması yakar ve büyür.","Dash explosions grow and burn."}},
 {a="leech",b="renew",name={"YAŞAYAN FENER","LIVING LANTERN"},desc={"Öldürme şifası iki katına çıkar.","Healing from kills is doubled."}}
}
C.ui={
 title={"AYAZ FENERİ","FROST LANTERN"},subtitle={"KAYIP ŞAFAĞIN BEŞ KIVILCIMI","FIVE SPARKS OF A LOST DAWN"},
 new={"Yeni yolculuk","New journey"},continue={"Yolculuğa devam","Continue journey"},workshop={"Fener atölyesi","Lantern workshop"},
 help={"Kontroller ve rehber","Controls and guide"},settings={"Ayarlar","Settings"},quit={"Çıkış","Quit"},back={"Geri","Back"},resume={"Devam","Resume"},
 pause={"YOLCULUK DURAKLADI","JOURNEY PAUSED"},menu={"Kaydet ve ana menü","Save and title"},attack={"SALDIR","ATTACK"},dash={"ATIL","DASH"},skill={"FENER","LANTERN"},heal={"İKSİR","POTION"},use={"ETKİLEŞ","USE"},
 route={"BİR SONRAKİ YOLU SEÇ","CHOOSE YOUR NEXT PATH"},reward={"BİR LÜTUF SEÇ","CHOOSE A BOON"},bossreward={"BEKÇİNİN MİRASI","KEEPER'S LEGACY"},
 combat={"Çatışma","Combat"},elite={"Seçkin avı","Elite hunt"},treasure={"Hazine","Treasure"},shop={"Gezgin tüccar","Travelling merchant"},shrine={"Eski sunak","Ancient shrine"},rest={"Sığınak","Sanctuary"},boss={"Bölüm bekçisi","Keeper"},
 clear={"ODA TEMİZLENDİ","ROOM CLEARED"},exit={"Kapıya git · E / X","Reach the gate · E / X"},locked={"Önce bekçileri yen","Defeat the keepers first"},
 death={"FENER SÖNDÜ","THE LANTERN FADES"},deathbody={"Bu yolculuk sona erdi. Topladığın şafak kırıkları atölyede kalır.","This journey has ended. Your dawn shards remain in the workshop."},
 victory={"ŞAFAK GERİ DÖNDÜ","DAWN RETURNS"},victorybody={"Beş bekçi sustu. Taşın altında bekleyen şehir, fenerinin ışığıyla yeniden uyandı.","The five keepers are silent. The sleeping city awakens beneath your lantern's light."},
 chooseweapon={"YOLCULUK SİLAHINI SEÇ","CHOOSE YOUR STARTING WEAPON"},rank={"SEVİYE","RANK"},synergy={"BİRLİKTELİK","SYNERGY"},
 shrinebody={"Sunak bir bedel ister: azami canından 12 eksilt, nadir bir lütuf al. Ya da ışığından 18 can kazan.","The shrine asks a price: sacrifice 12 maximum health for a rare boon. Or accept 18 healing."},
 sacrifice={"12 azami can sun · nadir lütuf","Offer 12 max health · rare boon"},blessing={"18 can yenile","Restore 18 health"},
 buyheal={"30 can yenile · 35 altın","Heal 30 · 35 gold"},buypotion={"Bir iksir · 45 altın","One potion · 45 gold"},buyboon={"Rastgele lütuf · 65 altın","Random boon · 65 gold"},leave={"Yola devam","Continue onward"},
 healthmeta={"Kalıcı can +5","Permanent health +5"},powermeta={"Kalıcı hasar +%5","Permanent damage +5%"},flaskmeta={"Başlangıç iksiri +1","Starting potions +1"},
 shards={"ŞAFAK KIRIĞI","DAWN SHARDS"},gold={"ALTIN","GOLD"},runs={"YOLCULUK","JOURNEYS"},kills={"AV","KILLS"},floor={"BÖLGE","REGION"},
 map={"YOL HARİTASI","PATH MAP"},build={"LÜTUFLARIN","YOUR BOONS"},empty={"Henüz lütuf yok. İlk odayı temizle.","No boons yet. Clear the first room."},
 sound={"Ses","Sound"},music={"Müzik","Music"},volume={"Efekt sesi","Effects volume"},shake={"Ekran sarsıntısı","Screen shake"},autoaim={"Otomatik nişan","Auto aim"},fx={"Atmosfer","Atmosphere"},fxlow={"DÜŞÜK","LOW"},fxmid={"ORTA","MEDIUM"},fxhigh={"YÜKSEK","HIGH"},language={"Dil / Language","Dil / Language"},on={"AÇIK","ON"},off={"KAPALI","OFF"},
 helpbody={"WASD / sol çubuk: hareket. Fare / sağ çubuk: nişan. Sol tık, J veya ZR: saldırı. Space / B: atılma (kısa dokunulmazlık). Q / Y: alan feneri. H / L: iksir. E / X: kapı, sandık, sunak. Tab / eksi: lütuflar ve rota. Esc / artı: duraklat. Dokunmatik: sol alan hareket, sağ alan otomatik nişanla saldırı; alt düğmeler özel eylemler. Ölüm yolculuğu bitirir. Her odadan sonra üç lütuftan birini seç; uyumlu mühürleri birleştir. Atölye geliştirmeleri kalıcıdır. Kayıtlar oda geçişlerinde ve duraklamada tutulur.","WASD / left stick: move. Mouse / right stick: aim. Left click, J or ZR: attack. Space / B: dash (brief invulnerability). Q / Y: lantern burst. H / L: potion. E / X: gate, chest, shrine. Tab / minus: build and route. Esc / plus: pause. Touch: move on the left, attack with auto aim on the right; bottom buttons perform special actions. Death ends a journey. Choose one of three boons after each fight; combine compatible seals. Workshop upgrades persist. Progress saves at room transitions and when paused."},
 ready={"HAZIR","READY"},unaffordable={"Yeterli altın yok","Not enough gold"},maxed={"TAMAMLANDI","MAXED"},cost={"BEDEL","COST"},
 savehint={"Yerel kayıt · İnternet gerekmez","Local save · No internet required"},seed={"TOHUM","SEED"},
 resthint={"Sığınak: 35 can ve bir iksir. E / X","Sanctuary: 35 health and one potion. E / X"},
 treasurehint={"Sandığı aç · E / X","Open the chest · E / X"},interacthint={"E / X ile etkileş","E / X to interact"}
}
return C
