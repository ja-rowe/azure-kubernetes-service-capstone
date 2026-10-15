#!/usr/bin/env python3
"""Apply the release policy to a Trivy JSON report.

    evaluate.py --report image.json --name carts --block CRITICAL --warn HIGH --summary out.md

Exit codes: 0 = pass (possibly with warnings), 3 = blocked by policy, 2 = no/invalid result.
A missing or unreadable report is never treated as clean.

Blocking: vulnerabilities at a block severity *with a fixed version available*, and failed
misconfiguration checks at a block severity. Warnings: the same at a warn severity (never blocks).
Findings suppressed by a reviewed exception are counted separately.
"""
import argparse
import collections
import json
import pathlib
import sys


def severities(value):
    return {s.strip().upper() for s in value.split(",") if s.strip()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--block", default="CRITICAL")
    ap.add_argument("--warn", default="HIGH")
    ap.add_argument("--summary", required=True)
    args = ap.parse_args()
    block, warn = severities(args.block), severities(args.warn) - severities(args.block)

    try:
        report = json.loads(pathlib.Path(args.report).read_text())
    except (OSError, ValueError) as err:
        print(f"##vso[task.logissue type=error]{args.name}: no usable scan result ({err}); treated as failed, not clean")
        sys.exit(2)

    counts = collections.Counter()
    blocked, warned, suppressed = [], [], 0
    for result in report.get("Results") or []:
        target = result.get("Target", "")
        for v in result.get("Vulnerabilities") or []:
            sev = v.get("Severity", "UNKNOWN")
            counts[sev] += 1
            line = f'{v.get("VulnerabilityID")} {sev} {v.get("PkgName")} {v.get("InstalledVersion")} -> {v.get("FixedVersion") or "no fix"} ({target})'
            if sev in block and v.get("FixedVersion"):
                blocked.append(line)
            elif sev in block or sev in warn:
                warned.append(line)
        for m in result.get("Misconfigurations") or []:
            if m.get("Status") != "FAIL":
                continue
            sev = m.get("Severity", "UNKNOWN")
            counts[sev] += 1
            line = f'{m.get("ID")} {sev} {m.get("Title")} ({target})'
            if sev in block:
                blocked.append(line)
            elif sev in warn:
                warned.append(line)
        suppressed += len(result.get("ExperimentalModifiedFindings") or []) + len(result.get("ModifiedFindings") or [])

    digest = ((report.get("Metadata") or {}).get("RepoDigests") or [""])[0]
    verdict = "BLOCKED" if blocked else ("PASS with warnings" if warned else "PASS")
    with open(args.summary, "a") as out:
        out.write(f"| {args.name} | {digest or report.get('ArtifactName', '')} | "
                  f"{counts['CRITICAL']} | {counts['HIGH']} | {counts['MEDIUM']} | {counts['LOW']} | "
                  f"{suppressed} | **{verdict}** |\n")

    for line in warned[:25]:
        print(f"##vso[task.logissue type=warning]{args.name}: {line}")
    if len(warned) > 25:
        print(f"##vso[task.logissue type=warning]{args.name}: … and {len(warned) - 25} more warnings (see report)")
    if blocked:
        for line in blocked[:25]:
            print(f"##vso[task.logissue type=error]{args.name}: {line}")
        print(f"{args.name}: BLOCKED by policy ({len(blocked)} finding(s) at {','.join(sorted(block))})")
        sys.exit(3)
    print(f"{args.name}: {verdict} ({len(warned)} warning(s), {suppressed} excepted)")


if __name__ == "__main__":
    main()
