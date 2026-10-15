#!/usr/bin/env python3
"""Validate ci/security/exceptions.yaml and render the Trivy ignore file for one scan target.

    render_exceptions.py --scope carts --out trivyignore.yaml [--exceptions FILE] [--policy FILE]

Fails (exit 1) if any entry is incomplete, has an unknown kind, or is granted for longer than
policy.yaml's exceptions.max_days. Expired entries are rendered with `expired_at`, so Trivy no
longer suppresses them and the finding is evaluated (and blocks) again.
"""
import argparse
import datetime as dt
import pathlib
import sys

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML is required (the scan templates create a venv with pyyaml==6.0.2)")

HERE = pathlib.Path(__file__).resolve().parent
REQUIRED = ("id", "kind", "scope", "owner", "approver", "rationale", "created", "expires")
KINDS = {"vulnerability": "vulnerabilities", "misconfiguration": "misconfigurations"}


def as_date(value, field, entry_id):
    if isinstance(value, dt.date):
        return value
    try:
        return dt.date.fromisoformat(str(value))
    except ValueError:
        raise SystemExit(f"exception {entry_id}: {field} is not a date (yyyy-mm-dd): {value!r}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--scope", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--exceptions", default=HERE / "exceptions.yaml")
    ap.add_argument("--policy", default=HERE / "policy.yaml")
    args = ap.parse_args()

    max_days = yaml.safe_load(open(args.policy))["exceptions"]["max_days"]
    entries = (yaml.safe_load(open(args.exceptions)) or {}).get("exceptions") or []
    today = dt.date.today()

    errors, rendered, active, expired = [], {v: [] for v in KINDS.values()}, 0, 0
    for i, e in enumerate(entries):
        eid = e.get("id", f"#{i}")
        missing = [f for f in REQUIRED if not e.get(f)]
        if missing:
            errors.append(f"exception {eid}: missing {', '.join(missing)}")
            continue
        if e["kind"] not in KINDS:
            errors.append(f"exception {eid}: kind must be one of {', '.join(KINDS)}")
            continue
        created, expires = as_date(e["created"], "created", eid), as_date(e["expires"], "expires", eid)
        if (expires - created).days > max_days:
            errors.append(f"exception {eid}: granted for {(expires - created).days} days (max {max_days})")
            continue
        scope = e["scope"] if isinstance(e["scope"], list) else [e["scope"]]
        if args.scope not in scope and "*" not in scope:
            continue
        if expires < today:
            expired += 1
        else:
            active += 1
        rendered[KINDS[e["kind"]]].append({
            "id": e["id"],
            "expired_at": expires,
            "statement": f'{e["rationale"]} (owner: {e["owner"]}; approved by: {e["approver"]}; created {created})',
        })

    if errors:
        print("\n".join(errors), file=sys.stderr)
        sys.exit(1)

    out = {k: v for k, v in rendered.items() if v}
    pathlib.Path(args.out).write_text(yaml.safe_dump(out, sort_keys=False) if out else "{}\n")
    print(f"exceptions for {args.scope}: {active} active, {expired} expired (no longer suppressing)")


if __name__ == "__main__":
    main()
