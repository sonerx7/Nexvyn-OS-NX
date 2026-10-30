# Melodi Çalar (Python)

[English](README.md) · **Türkçe**

Python ile nota nota melodi çalar: piyano rulosu, tempo, dalga biçimi, döngü, kendi melodinizi yazma ve geri çağırmaların ne zaman çalıştığını gösteren canlı günlük.

| | |
|---|---|
| Kimlik | `com.sonerx7.demo.audio-py` |
| Dil | Python (pocketpy) |
| En düşük SDK | 1.3 |
| İzinler | yok |
| Kumanda | imleci sürer |
| Pencere | 900 × 560, yeniden boyutlanır |

## Ne öğretir

- `timer.after(saniye, fn)` zinciri: her nota bir sonrakini planlar; `timer.cancel(id)` zinciri durdurur
- Bağlı metotlar, lambda'lar ve iç içe fonksiyonlar geri çağırma olarak (konsoldaki Python'da async/await yok)
- `ui.prompt(..., callback)` ile melodi yazmak, hatalı girişte `ui.alert(..., callback)` (düğme sırası 0'dan başlar)
- Geri çağırmaların her zaman sonraki bir karede çalıştığını gösteren günlük
- Nota listesinden piyano rulosu ve `update` + `sys.time` ile geri çağırmalar arasında akıcı oynatma çizgisi
- Başka bir `.py` dosyasını `import` etmek (melody.py) ve pocketpy kısıtları (`re` yok: elle ayrıştırma)

**Kullanılan API'ler:** `timer.after/cancel`, `audio.tone` (anahtar kelimelerle / with keywords), `ui.prompt/alert/dropdown/segmented/slider/checkbox/button/group`, `gfx.clip/rect/line/text`, `store`

**Kontroller:** Boşluk: çal/durdur · E: kendi melodini yaz (ör. `C4 E4 G4:2 R:0.5 F#4:0.5`).

## Kod parçası

Zincirdeki bir halka: notayı çal, bir sonrakini `timer.after` ile planla ve kimliğini sakla ki `stop()` iptal edebilsin.

```python
def next_note(self):
    self.pending = None
    self.index += 1
    if self.index >= len(self.notes):
        ...                                   # end, or start again when looping
    midi, beats = self.notes[self.index]
    seconds = beats * 60.0 / self.bpm
    if midi is not None:
        audio.tone(melody.freq(midi), sec=seconds * 0.92, volume=0.45, wave=WAVES[self.wave])
    self.note_at = sys.time()
    self.pending = timer.after(seconds, self.next_note)   # a bound method is a fine callback

def stop(self):
    if self.pending is not None:
        timer.cancel(self.pending)            # the scheduled callback never runs
```

## Çalıştırma

`source/` klasörünü `MelodyPlayerPython.nxvapp` adıyla `sdmc:/NexvynOS/Applications/` içine kopyalayın ya da `python tools/nxvapp_pack.py` ile tek dosya paketleyin. Dosyalar: `main.py` (302 satır), `melody.py` (53 satır), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Bilgisayarda denetim (Nexvyn OS kaynak deposunun kökünden; `<Nexvyn-OS-NX>` bu deponun klasörüdür):

    python tools/py_check.py <Nexvyn-OS-NX>/SDK/Samples/python/audio-py/source --frames 900

## Sürümler

| Sürüm | Değişiklik |
|---|---|
| 1.0 | İlk sürüm. |
