-- Passphrase word lists (Turkish and English). Duplicates are removed when the module loads.
local tr = {
  "elma", "nehir", "taş", "bulut", "kaplan", "piyano", "roket", "bahçe", "gümüş", "orman",
  "mum", "mermer", "pencere", "köprü", "gezegen", "kahve", "ejder", "çekiç", "ada", "ceket",
  "kedi", "limon", "ayna", "iğne", "portakal", "biber", "kuvars", "tavşan", "eyer", "tünel",
  "kadife", "ceviz", "sarı", "zebra", "çapa", "sepet", "kale", "çöl", "motor", "şahin",
  "buzul", "liman", "orkide", "papağan", "tüy", "yastık", "kurdele", "kereste", "şemsiye", "vadi",
  "büyücü", "yoğurt", "palamut", "esinti", "kaktüs", "yunus", "kıvılcım", "galaksi", "ufuk", "fildişi",
  "yasemin", "fener", "akçaağaç", "kartal", "masal", "bal", "buz", "jöle", "kano", "lagün",
  "mıknatıs", "erişte", "zeytin", "çakıl", "bulmaca", "radar", "somon", "demlik", "lale", "girdap",
  "gözleme", "yat", "fermuar", "kobalt", "domino", "yankı", "fosil", "fındık", "nilüfer", "mango",
  "nikel", "opal", "prizma", "bilmece", "tango", "buhar", "bıyık", "deniz", "güneş", "yıldız",
  "kum", "rüzgar", "ağaç", "çiçek", "dağ", "göl", "kar", "yağmur", "şimşek", "ışık",
  "gölge", "sabah", "akşam", "gece", "şehir", "köy", "yol", "kapı", "anahtar", "kitap",
  "kalem", "defter", "saat", "takvim", "harita", "pusula", "çadır", "kamp", "balık", "kuş",
  "arı", "karınca", "kelebek", "sincap", "tilki", "kurt", "ayı", "geyik", "baykuş", "martı",
  "leylek", "inci", "mercan", "yosun", "ceylan", "fırtına", "gökkuşağı", "şelale", "mağara", "volkan",
  "çınar", "meşe", "söğüt", "kiraz", "üzüm", "incir", "nar", "ayva", "badem", "pamuk",
  "ipek", "keman", "davul", "flüt", "gitar", "şarkı", "dans", "resim", "heykel", "müze",
}

local en = {
  "apple", "river", "stone", "cloud", "tiger", "piano", "rocket", "garden", "silver", "forest",
  "candle", "marble", "window", "bridge", "planet", "coffee", "dragon", "hammer", "island", "jacket",
  "kitten", "lemon", "mirror", "needle", "orange", "pepper", "quartz", "rabbit", "saddle", "tunnel",
  "velvet", "walnut", "yellow", "zebra", "anchor", "basket", "castle", "desert", "engine", "falcon",
  "glacier", "harbor", "igloo", "jungle", "kettle", "ladder", "meadow", "nectar", "oyster", "pillow",
  "quiver", "ribbon", "sunset", "timber", "umbrella", "valley", "wizard", "yogurt", "acorn", "breeze",
  "cactus", "dolphin", "ember", "feather", "galaxy", "horizon", "ivory", "jasmine", "koala", "lantern",
  "maple", "nugget", "orchid", "parrot", "quill", "raven", "shadow", "thunder", "unicorn", "violet",
  "willow", "blossom", "comet", "daisy", "eagle", "fable", "goblin", "honey", "icicle", "jelly",
  "kayak", "lagoon", "magnet", "noodle", "olive", "pebble", "puzzle", "radar", "salmon", "teapot",
  "tulip", "vortex", "waffle", "yacht", "zipper", "banjo", "cobalt", "domino", "echo", "fossil",
  "gravel", "hazel", "indigo", "juniper", "lotus", "mango", "nickel", "opal", "prism", "riddle",
  "sphinx", "tango", "urchin", "vapor", "whisker", "ocean", "summit", "canyon", "meteor", "harvest",
  "compass", "lighthouse", "pirate", "voyage", "cabin", "frost", "spark", "orbit", "nebula", "copper",
}

local function dedupe(list)
  local seen, out = {}, {}
  for _, w in ipairs(list) do
    if not seen[w] then
      seen[w] = true
      out[#out + 1] = w
    end
  end
  return out
end

return {tr = dedupe(tr), en = dedupe(en)}
