-- Lesson content for the typing tutor.
local L = {}

L.rows = {
  tr = {home = "asdfghjklşi", top = "qwertyuıopğü", bottom = "zxcvbnmöç", numbers = "1234567890"},
  en = {home = "asdfghjkl;", top = "qwertyuiop", bottom = "zxcvbnm,.", numbers = "1234567890"},
}

L.keyboard = {
  tr = {"1234567890*-", "qwertyuıopğü", "asdfghjklşi,", "zxcvbnmöç."},
  en = {"1234567890-=", "qwertyuiop[]", "asdfghjkl;'", "zxcvbnm,./"},
}

L.turkishWords = {
  "çiçek", "ağaç", "ışık", "göğüs", "şüphe", "üzüm", "İstanbul", "öğretmen", "kılıç", "düşünce", "çağ", "yağmur",
  "güneş", "ıslak", "Iğdır", "Şişli", "Ödemiş", "Ürgüp", "Çeşme", "öğle", "değişim", "şarkı", "çocuk", "gülümse",
  "dağ", "bağış", "İzmir", "Ağrı", "sığınak", "çığlık", "gümüş", "öğrenci", "şükür", "ılık", "kuş", "çörek",
}

L.sentences = {
  tr = {
    "Bugün hava çok güzel, parka yürüyüşe çıkalım.",
    "Kitap okumak insanın ufkunu genişletir.",
    "Sabah erken kalkan yol alır.",
    "Pazartesi günü toplantı saat onda başlayacak.",
    "Ağaç yaşken eğilir.",
    "Damlaya damlaya göl olur.",
    "İstanbul'un tarihi yarımadası çok etkileyici.",
    "Küçük adımlar büyük değişimlere yol açar.",
    "Çay demlenirken kahvaltı sofrasını hazırladık.",
    "Öğrenmenin yaşı yoktur, her gün yeni bir şey öğren.",
  },
  en = {
    "The quick brown fox jumps over the lazy dog.",
    "Practice makes perfect, so keep typing every day.",
    "A journey of a thousand miles begins with a single step.",
    "She sells seashells by the seashore.",
    "Good habits are built one keystroke at a time.",
    "Every expert was once a beginner.",
    "The early bird catches the worm.",
    "Typing fast is great, but typing accurately is better.",
    "Bright stars filled the quiet winter sky.",
    "Never stop learning, because life never stops teaching.",
  },
}

-- the most common English words, for the Common words lesson and the one-minute test
L.commonWords = {
  "the", "be", "to", "of", "and", "a", "in", "that", "have", "it", "for", "not", "on", "with", "he", "as", "you", "do",
  "at", "this", "but", "his", "by", "from", "they", "we", "say", "her", "she", "or", "an", "will", "my", "one", "all",
  "would", "there", "their", "what", "so", "up", "out", "if", "about", "who", "get", "which", "go", "me", "when",
  "make", "can", "like", "time", "no", "just", "him", "know", "take", "people", "into", "year", "your", "good",
  "some", "could", "them", "see", "other", "than", "then", "now", "look", "only", "come", "its", "over", "think",
  "also", "back", "after", "use", "two", "how", "our", "work", "first", "well", "way", "even", "new", "want",
  "because", "any", "these", "give", "day", "most", "us",
}

return L
