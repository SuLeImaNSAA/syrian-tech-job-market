"""Summarize and audit the private source CSV using the Python standard library.

Usage: python3 scripts/validate_source.py /path/to/jobs_raw.csv
Prints JSON; it does not write or change the source file.
"""
import csv
import json
import re
import sys
from collections import Counter
from pathlib import Path

EXPECTED = [
    "job_title", "company_name", "origin_type", "city", "country", "source",
    "experience_level", "experience_years_min", "experience_years_max",
    "job_type", "posted_date", "salary", "skills", "description",
]
SALARY = re.compile(r"^\s*\d+(?:\s*-\s*\d+)?\s*$")
ALIASES = {
    "react.js": "React", "react": "React",
    "express": "Express.js", "express.js": "Express.js",
    "bloc": "BLoC", "scrum": "Scrum", "llms": "LLM",
    "android development": "Android", "ios development": "iOS",
    "wireframes": "Wireframing", "eloquent": "Eloquent ORM",
}

def company(name):
    name = name.strip()
    low = name.lower()
    if low == "metamas":
        return "MetaMAS"
    if low == "metagate":
        return "MetaGate"
    if low in {"l-one", "l-one llc", "l-one l.l.c"}:
        return "L-One L.L.C"
    if low in {"unknown", "private company", "software company"}:
        return "Unknown"
    return name

def main(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != EXPECTED:
            raise ValueError(f"Unexpected CSV columns: {reader.fieldnames!r}")
        rows = list(reader)
    skills = Counter()
    for row in rows:
        unique = {
            ALIASES.get(item.strip().lower(), item.strip())
            for item in row["skills"].split(",") if item.strip() and item.strip() != "NULL"
        }
        skills.update(unique)
    duplicates = Counter((r["job_title"], r["company_name"], r["posted_date"]) for r in rows)
    dates = [r["posted_date"] for r in rows if r["posted_date"] not in {"", "NULL"}]
    junior = [r for r in rows if r["experience_level"] == "Junior"]
    metrics = {
        "source_rows": len(rows),
        "canonical_companies": len({company(r["company_name"]) for r in rows}),
        "posting_date_min": min(dates, default=None),
        "posting_date_max": max(dates, default=None),
        "origin_type_counts": dict(sorted(Counter(r["origin_type"] for r in rows).items())),
        "salary_disclosed_count": sum(bool(SALARY.fullmatch(r["salary"])) for r in rows),
        "salary_missing_count": sum(r["salary"] in {"", "NULL"} for r in rows),
        "junior_postings": len(junior),
        "junior_min_years": dict(sorted(Counter(r["experience_years_min"] for r in junior).items())),
        "junior_missing_max_years": sum(r["experience_years_max"] in {"", "NULL"} for r in junior),
        "possible_duplicate_groups": sum(v > 1 for v in duplicates.values()),
        "possible_duplicate_extra_rows": sum(v - 1 for v in duplicates.values() if v > 1),
        "top_skills": [{"skill": name, "postings": count} for name, count in
                       sorted(skills.items(), key=lambda kv: (-kv[1], kv[0]))[:10]],
    }
    print(json.dumps(metrics, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/validate_source.py /path/to/jobs_raw.csv")
    main(sys.argv[1])
