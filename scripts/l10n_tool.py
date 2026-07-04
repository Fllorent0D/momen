#!/usr/bin/env python3
"""Outils l10n pour les String Catalogs (.xcstrings).

- extract  : écrit un JSON {clé_source_fr: valeur_en} pour donner le contexte aux
             traducteurs (clé = source française, valeur = référence anglaise).
- apply    : injecte une langue depuis un map {clé_source_fr: traduction} dans un
             ou plusieurs catalogs (n'ajoute que pour les clés présentes).

Usage:
  python3 scripts/l10n_tool.py extract <catalog.xcstrings> <out.json>
  python3 scripts/l10n_tool.py apply <lang> <map.json> <catalog.xcstrings> [<catalog2> ...]
"""
import json
import sys


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dump(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


def en_value(entry, key):
    loc = entry.get("localizations", {})
    unit = loc.get("en", {}).get("stringUnit", {})
    return unit.get("value", key)


def extract(catalog, out):
    data = load(catalog)
    result = {k: en_value(v, k) for k, v in data["strings"].items()}
    dump(out, result)
    print(f"extracted {len(result)} strings -> {out}")


def apply(lang, mappath, catalogs):
    mapping = load(mappath)
    for catalog in catalogs:
        data = load(catalog)
        strings = data["strings"]
        n = 0
        for key, translation in mapping.items():
            if key not in strings:
                continue
            if not isinstance(translation, str) or translation == "":
                continue
            entry = strings[key]
            loc = entry.setdefault("localizations", {})
            loc[lang] = {"stringUnit": {"state": "translated", "value": translation}}
            n += 1
        dump(catalog, data)
        print(f"applied {lang}: {n} strings -> {catalog}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "extract":
        extract(sys.argv[2], sys.argv[3])
    elif cmd == "apply":
        apply(sys.argv[2], sys.argv[3], sys.argv[4:])
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
