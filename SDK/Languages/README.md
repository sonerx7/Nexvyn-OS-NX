# Languages

**English** · [Türkçe](README.tr.md)

A quick start and a ready-to-copy `template/` folder that passes its checker, for every language.

| Language | Guide | Template | Checker | SDK |
|---|---|---|---|---|
| Lua 5.4 | [lua/README.md](lua/README.md) | [lua/template](lua/template/) | `python tools/lua_check.py` | 1.0 |
| JavaScript | [javascript/README.md](javascript/README.md) | [javascript/template](javascript/template/) | `node tools/js_check.mjs` | 1.1 |
| Python | [python/README.md](python/README.md) | [python/template](python/template/) | `python tools/py_check.py` | 1.3 |
| Squirrel 3.2 | [squirrel/README.md](squirrel/README.md) | [squirrel/template](squirrel/template/) | `python tools/rt_check.py` | 1.5 |
| C (TinyCC) | [c/README.md](c/README.md) | [c/template](c/template/) | `python tools/rt_check.py` | 1.5 |
| Java 8 (miniJVM) | [java/README.md](java/README.md) | [java/template](java/template/) | `python tools/rt_check.py` | 1.5 |

The templates are the same app (a counter, a menu, `store`, translations in five languages), so the languages can be
compared side by side. `python SDK/Tools/nxv/nxv.py new <lang> "<Name>"` copies one and fills in the id and name. The
checkers live in the Nexvyn OS source repository (`nxv check` with `--sdk` runs all of them).
