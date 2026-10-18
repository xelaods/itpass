#!/usr/bin/env python3
"""tools/data/*.py の問題・用語を検証して ITPass/Resources/bank.json に書き出す。

使い方: python3 tools/build_bank.py
"""
import hashlib
import json
import random
import re
import sys
from collections import Counter
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "data"))

from common import CATEGORIES  # noqa: E402
import strategy, management, technology, terms  # noqa: E402

OUT = ROOT.parent / "ITPass" / "Resources" / "bank.json"
FIELD_OF = {c[0]: c[1] for c in CATEGORIES}


def sid(prefix, text):
    return prefix + hashlib.sha1(text.encode("utf-8")).hexdigest()[:10]


def numeric_key(s):
    """数値の選択肢を小さい順に並べるためのキー。数値でなければ None。"""
    m = re.search(r"10の(マイナス)?(\d+)乗", s)
    if m:
        n = int(m.group(2))
        return -n if m.group(1) else n
    m = re.match(r"^\s*(\d+)/(\d+)\s*$", s)
    if m:
        return float(Fraction(int(m.group(1)), int(m.group(2))))
    m = re.match(r"^[\s＝]*([0-9][0-9,]*(?:\.[0-9]+)?)", s)
    if m and "," not in s.replace(m.group(1), ""):
        try:
            return float(m.group(1).replace(",", ""))
        except ValueError:
            return None
    return None


def order_choices(qid, choices, fixed):
    correct = choices[0]
    if fixed:
        keys = [numeric_key(c) for c in choices]
        if all(k is not None for k in keys) and len(set(keys)) == len(keys):
            ordered = [c for _, c in sorted(zip(keys, choices))]
            return ordered, ordered.index(correct)
    rng = random.Random(qid)
    ordered = choices[:]
    rng.shuffle(ordered)
    return ordered, ordered.index(correct)


def main():
    errors = []
    questions = []
    seen = set()
    for module in (strategy, management, technology):
        for q in module.QUESTIONS:
            if q.category not in FIELD_OF:
                errors.append(f"未知の分類 {q.category}: {q.text[:20]}")
            if len(set(q.choices)) != 4:
                errors.append(f"選択肢の重複: {q.text[:30]}")
            if q.difficulty not in (1, 2, 3):
                errors.append(f"難易度不正: {q.text[:30]}")
            qid = sid("q", q.text)
            if qid in seen:
                errors.append(f"問題の重複: {q.text[:30]}")
            seen.add(qid)
            choices, answer = order_choices(qid, q.choices, q.fixed)
            questions.append({
                "id": qid,
                "field": FIELD_OF.get(q.category, "strategy"),
                "category": q.category,
                "difficulty": q.difficulty,
                "text": q.text,
                "choices": choices,
                "answer": answer,
                "explanation": q.explanation,
                "fixed": q.fixed,
            })

    term_list = []
    seen_terms = set()
    for t in terms.TERMS:
        if t.category not in FIELD_OF:
            errors.append(f"未知の分類 {t.category}: {t.term}")
        if t.term in seen_terms:
            errors.append(f"用語の重複: {t.term}")
        seen_terms.add(t.term)
        term_list.append({
            "id": sid("t", t.term),
            "field": FIELD_OF.get(t.category, "strategy"),
            "category": t.category,
            "term": t.term,
            "reading": t.reading,
            "definition": t.definition,
        })

    if errors:
        print("\n".join(errors))
        sys.exit(1)

    bank = {
        "version": 1,
        "categories": [
            {"id": c[0], "field": c[1], "name": c[2], "symbol": c[3]} for c in CATEGORIES
        ],
        "questions": questions,
        "terms": term_list,
    }
    OUT.write_text(json.dumps(bank, ensure_ascii=False, indent=1), encoding="utf-8")

    by_field = Counter(q["field"] for q in questions)
    by_cat = Counter(q["category"] for q in questions)
    answers = Counter(q["answer"] for q in questions)
    print(f"問題 {len(questions)} 問  {dict(by_field)}")
    print(f"用語 {len(term_list)} 語")
    print("正解位置の分布", dict(sorted(answers.items())))
    for c in CATEGORIES:
        print(f"  {c[2]}: 問題 {by_cat[c[0]]} / 用語 {sum(1 for t in term_list if t['category']==c[0])}")


if __name__ == "__main__":
    main()
