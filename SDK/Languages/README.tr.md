# Diller

[English](README.md) · **Türkçe**

Her dil için hızlı başlangıç ve denetleyiciden geçen, kopyalanmaya hazır bir `template/` klasörü.

| Dil | Rehber | Şablon | Denetleyici | SDK |
|---|---|---|---|---|
| Lua 5.4 | [lua/README.md](lua/README.tr.md) | [lua/template](lua/template/) | `python tools/lua_check.py` | 1.0 |
| JavaScript | [javascript/README.md](javascript/README.tr.md) | [javascript/template](javascript/template/) | `node tools/js_check.mjs` | 1.1 |
| Python | [python/README.md](python/README.tr.md) | [python/template](python/template/) | `python tools/py_check.py` | 1.3 |
| Squirrel 3.2 | [squirrel/README.md](squirrel/README.tr.md) | [squirrel/template](squirrel/template/) | `python tools/rt_check.py` | 1.5 |
| C (TinyCC) | [c/README.md](c/README.tr.md) | [c/template](c/template/) | `python tools/rt_check.py` | 1.5 |
| Java 8 (miniJVM) | [java/README.md](java/README.tr.md) | [java/template](java/template/) | `python tools/rt_check.py` | 1.5 |

Şablonlar aynı uygulamadır (sayaç, menü, `store`, beş dilde çeviri), böylece diller yan yana karşılaştırılabilir.
`python SDK/Tools/nxv/nxv.py new <dil> "<Ad>"` bir şablonu kopyalayıp kimliği ve adı doldurur. Denetleyiciler Nexvyn OS
kaynak deposundadır (`--sdk` ile `nxv check` hepsini çağırır).
