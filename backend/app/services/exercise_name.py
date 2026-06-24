"""Canonicalization of free-form exercise names.

Mirrors the iOS `ExerciseName` logic so the backend groups/merges the same
movement the same way the client does: case + punctuation + whitespace folding,
gym-tuned singularization, and a curated set of synonyms. Used by the bulk
rename/merge endpoint to match variants like "Lat Pulldown" / "Lat Pulldowns".
"""
from __future__ import annotations

import re

_PLURAL_SUFFIXES = ("ches", "shes", "xes", "zes", "ses")

# Groups of names that mean the same movement; the first entry is canonical.
# Every entry is matched in its normalized form, so list natural spellings.
_SYNONYM_GROUPS: list[list[str]] = [
    ["Leg Press", "Seated Leg Press", "Horizontal Leg Press", "Machine Leg Press"],
    ["Lat Pulldown", "Lat Pull Down"],
    ["Chest Press", "Machine Chest Press", "Seated Chest Press"],
    ["Shoulder Press", "Seated Shoulder Press", "Overhead Press", "OHP"],
    ["Romanian Deadlift", "RDL"],
]


def _singularize(word: str) -> str:
    """Best-effort English singularization tuned for gym vocabulary."""
    if len(word) <= 3:
        return word                       # abs, leg, row, dip...
    if word.endswith("ss"):
        return word                       # press, cross
    if word.endswith("ies"):
        return word[:-3] + "y"            # flies -> fly
    if word.endswith("ves"):
        return word[:-3] + "f"            # calves -> calf
    for suffix in _PLURAL_SUFFIXES:
        if word.endswith(suffix):
            return word[:-2]              # crunches -> crunch, presses -> press
    if word.endswith("s"):
        return word[:-1]
    return word


def normalize(raw: str) -> str:
    """Lowercased, de-punctuated, whitespace-collapsed, singularized form."""
    lowered = (raw or "").lower()
    spaced = re.sub(r"[^a-z0-9]+", " ", lowered)
    words = [_singularize(w) for w in spaced.split()]
    return " ".join(words)


def _build_aliases() -> dict[str, str]:
    aliases: dict[str, str] = {}
    for group in _SYNONYM_GROUPS:
        if not group:
            continue
        canonical = normalize(group[0])
        for variant in group:
            aliases[normalize(variant)] = canonical
    return aliases


_ALIASES = _build_aliases()


def canonical_key(raw: str) -> str:
    """Stable key used to group/merge exercises that are really the same thing."""
    normalized = normalize(raw)
    return _ALIASES.get(normalized, normalized)


def same_exercise(a: str, b: str) -> bool:
    return canonical_key(a) == canonical_key(b)
