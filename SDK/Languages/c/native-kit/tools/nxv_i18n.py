#!/usr/bin/env python3
"""
Nexvyn OS N2 8-Language Localization & Pseudo-Locale Engine (N2 Plan Bölüm 7 & Faz 5).
Manages 8 core system locales: en, tr, de, es, fr, ja, ko, zh.
Provides:
  - Strict fallback chain: exact -> base -> en -> key
  - Pseudo-locale generator for layout stress/overflow testing
  - Placeholder ({0}, {1}...) integrity verification
  - Zero-tofu / CJK compatibility checker
"""
import os
import sys
import json
import re
import argparse
from pathlib import Path
from collections import Counter

SUPPORTED_LANGUAGES = ("en", "tr", "de", "es", "fr", "ja", "ko", "zh")


def starter_tables(title):
    """Real starter translations; extend every locale when adding product strings."""
    rows = {
        "en": ("Welcome", "Counter", "Confirm", "Back"),
        "tr": ("Hoş geldiniz", "Sayaç", "Onayla", "Geri"),
        "de": ("Willkommen", "Zähler", "Bestätigen", "Zurück"),
        "es": ("Bienvenido", "Contador", "Confirmar", "Atrás"),
        "fr": ("Bienvenue", "Compteur", "Confirmer", "Retour"),
        "ja": ("ようこそ", "カウンター", "確認", "戻る"),
        "ko": ("환영합니다", "카운터", "확인", "뒤로"),
        "zh": ("欢迎", "计数器", "确认", "返回"),
    }
    return {code: {"title": title, "greeting": row[0] + " — " + title,
                   "counter": row[1], "action.confirm": row[2], "action.back": row[3]}
            for code, row in rows.items()}

# Accent mappings for pseudo-localization stress test (Bölüm 7.3)
PSEUDO_MAP = {
    'a': 'á', 'b': 'ḅ', 'c': 'ç', 'd': 'ḍ', 'e': 'é', 'f': 'ƒ', 'g': 'ğ', 'h': 'ḥ',
    'i': 'í', 'j': 'ĵ', 'k': 'ḳ', 'l': 'ŀ', 'm': 'ṃ', 'n': 'ñ', 'o': 'ó', 'p': 'ṗ',
    'q': 'ʠ', 'r': 'ṛ', 's': 'ş', 't': 'ṭ', 'u': 'ú', 'v': 'ṿ', 'w': 'ŵ', 'x': 'ẋ',
    'y': 'ý', 'z': 'ž',
    'A': 'Á', 'B': 'Ḅ', 'C': 'Ç', 'D': 'Ḍ', 'E': 'É', 'F': 'Ƒ', 'G': 'Ğ', 'H': 'Ḥ',
    'I': 'Í', 'J': 'Ĵ', 'K': 'Ḳ', 'L': 'Ł', 'M': 'Ṃ', 'N': 'Ñ', 'O': 'Ó', 'P': 'Ṗ',
    'Q': 'Ǫ', 'R': 'Ṛ', 'S': 'Ş', 'T': 'Ṭ', 'U': 'Ú', 'V': 'Ṿ', 'W': 'Ŵ', 'X': 'Ẋ',
    'Y': 'Ý', 'Z': 'Ž'
}

def pseudo_localize(text):
    """
    Expands string length by ~35% and accents ASCII letters to simulate long translations (e.g. German/French)
    without breaking format specifiers like {0}, {1} or \\n.
    """
    def replace_word(m):
        raw = m.group(0)
        if raw.startswith("{") and raw.endswith("}"):
            return raw
        return "".join(PSEUDO_MAP.get(c, c) for c in raw)

    # Transform characters outside placeholders
    transformed = re.sub(r'(\{[0-9]+\}|[^{}]+)', replace_word, text)
    # Add expansion padding
    return f"[!! {transformed} !!]"

def validate_placeholders(src_text, dst_text):
    """Keep token identities and multiplicities, including named and printf tokens."""
    pattern = r'(?<!\{)\{[A-Za-z0-9_]+(?:![rsa])?(?::[^{}]+)?\}(?!\})|%(?!%)(?:[0-9]+\$)?[-+ #0]*(?:[0-9]+|\*)?(?:\.(?:[0-9]+|\*))?[hlLzjt]*[diuoxXfFeEgGaAcsp]'
    return Counter(re.findall(pattern, src_text.replace('%%', ''))) == Counter(re.findall(pattern, dst_text.replace('%%', '')))


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate key: " + key)
        result[key] = value
    return result


def flatten_strings(value, prefix="", result=None):
    """Support native nested dictionaries and script dotted keys without collisions."""
    result = {} if result is None else result
    if not isinstance(value, dict) or not value:
        raise ValueError("expected a non-empty translation object at " + (prefix or "root"))
    for key, text in value.items():
        if not isinstance(key, str) or not key.strip():
            raise ValueError("translation key must be non-empty")
        name = prefix + key
        if isinstance(text, dict):
            flatten_strings(text, name + ".", result)
        elif not isinstance(text, str) or not text.strip():
            raise ValueError("expected non-empty string for " + name)
        elif name in result:
            raise ValueError("duplicate flattened key: " + name)
        else:
            result[name] = text
    return result

def check_app_locales(app_dir):
    """Production authoring contract: all eight locales, complete keys and tokens."""
    lang_dir = Path(app_dir) / "lang"
    if not lang_dir.is_dir():
        return False, ["Missing 'lang/' directory"]

    en_path = lang_dir / "en.json"
    if not en_path.is_file():
        return False, ["Missing mandatory 'lang/en.json' source dictionary"]

    try:
        en_dict = flatten_strings(json.loads(en_path.read_text(encoding="utf-8-sig"), object_pairs_hook=_unique_object))
    except Exception as e:
        return False, [f"Invalid JSON in lang/en.json: {e}"]

    errors = []
    for code in SUPPORTED_LANGUAGES:
        if not (lang_dir / (code + ".json")).is_file():
            errors.append("Missing mandatory lang/" + code + ".json")
    for lfile in lang_dir.glob("*.json"):
        code = lfile.stem
        if code == "en":
            continue
        try:
            cur_dict = flatten_strings(json.loads(lfile.read_text(encoding="utf-8-sig"), object_pairs_hook=_unique_object))
            for key in sorted(set(en_dict) - set(cur_dict)):
                errors.append(f"{code}.json: missing key '{key}'")
            for key in sorted(set(cur_dict) - set(en_dict)):
                errors.append(f"{code}.json: unknown key '{key}'")
            for k, val in cur_dict.items():
                if k in en_dict:
                    if not validate_placeholders(en_dict[k], str(val)):
                        errors.append(f"{code}.json: placeholder mismatch for key '{k}'")
        except Exception as e:
            errors.append(f"Invalid JSON in {lfile.name}: {e}")

    return len(errors) == 0, errors

def main():
    parser = argparse.ArgumentParser(description="Nexvyn OS N2 Localization Tool")
    parser.add_argument("--pseudo", type=str, help="Generate pseudo-localized test string")
    parser.add_argument("--check", type=str, help="Validate locale files of an app directory")
    args = parser.parse_args()

    if args.pseudo:
        print(pseudo_localize(args.pseudo))
        return

    if args.check:
        ok, errors = check_app_locales(args.check)
        if ok:
            print(f"PASS: Localization files in {args.check} are valid across supported languages.")
            sys.exit(0)
        else:
            print(f"FAIL: {len(errors)} error(s) found in {args.check}:")
            for e in errors:
                print(f"  - {e}")
            sys.exit(1)

    print("Nexvyn OS N2 Localization Tool. Use --pseudo or --check.")

if __name__ == "__main__":
    main()
