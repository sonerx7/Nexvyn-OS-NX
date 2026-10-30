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

return L
