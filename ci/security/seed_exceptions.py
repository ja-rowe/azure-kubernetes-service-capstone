#!/usr/bin/env python3
"""Draft exception entries for the findings that currently block (baseline of a legacy backlog).

    seed_exceptions.py REPORT_DIR --owner "Name" --approver "Name" --rationale "..." [--days 90]

Reads every Trivy JSON report in REPORT_DIR (file name = scan target, e.g. carts.json, iac.json),
selects blocking findings (CRITICAL vulnerabilities with a fix, CRITICAL failed misconfigurations)
and prints YAML entries grouped by finding id with the targets as scope. Review before committing.
"""
import argparse
import datetime as dt
import json
import pathlib
import collections


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report_dir")
    ap.add_argument("--owner", required=True)
    ap.add_argument("--approver", required=True)
    ap.add_argument("--rationale", required=True)
    ap.add_argument("--days", type=int, default=90)
    ap.add_argument("--severity", default="CRITICAL")
    args = ap.parse_args()

    found = collections.defaultdict(lambda: {"kind": None, "scope": set()})
    for report in sorted(pathlib.Path(args.report_dir).rglob("*.json")):
        if report.name.endswith(".cdx.json"):
            continue
        target = report.stem.replace("_", ":", 1)  # report file names are the scope with ":" -> "_"
        data = json.loads(report.read_text())
        for result in data.get("Results") or []:
            for v in result.get("Vulnerabilities") or []:
                if v.get("Severity") == args.severity and v.get("FixedVersion"):
                    found[v["VulnerabilityID"]]["kind"] = "vulnerability"
                    found[v["VulnerabilityID"]]["scope"].add(target)
            for m in result.get("Misconfigurations") or []:
                if m.get("Status") == "FAIL" and m.get("Severity") == args.severity:
                    found[m["ID"]]["kind"] = "misconfiguration"
                    found[m["ID"]]["scope"].add(target)

    today = dt.date.today()
    expires = today + dt.timedelta(days=args.days)
    for fid in sorted(found):
        f = found[fid]
        scope = ", ".join(sorted(f["scope"]))
        print(f"  - id: {fid}\n    kind: {f['kind']}\n    scope: [{scope}]\n"
              f"    owner: {args.owner}\n    approver: {args.approver}\n"
              f"    rationale: {args.rationale}\n    created: {today}\n    expires: {expires}")
    print(f"# {len(found)} finding id(s)", flush=True)


if __name__ == "__main__":
    main()
