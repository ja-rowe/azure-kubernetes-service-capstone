# Security scanning policy

One scanner, one policy, applied the same way to container images, service dependencies and
infrastructure code. Defaults live in `policy.yaml`; the scan templates expose them as parameters
so a run can be made stricter or ignore exceptions on purpose (for example to demonstrate the gate).

## Scanner

- **Trivy**, pinned to `aquasec/trivy:0.75.0` (run as a container, version changed deliberately).
- Image scan → vulnerability report (JSON + SARIF) and a **CycloneDX SBOM** of the scanned image.
- Package scan (`trivy fs --offline-scan`) → vulnerabilities in the declared/locked dependencies of a
  service repo. Offline: no remote lookups (Maven Central rate-limits hosted agents and a 429 would
  otherwise make the scan inconclusive), so transitive Java dependencies are evaluated by the image
  scan of the built jar, which contains the fully resolved set.
- IaC scan (`trivy config`) → misconfigurations in Terraform source (or a plan JSON).

## Decision

| Finding | Default | Effect |
|---|---|---|
| CRITICAL vulnerability **with a fix available** | block | the scan step fails; promotion must not continue |
| CRITICAL vulnerability without a fix | warn | reported; nothing to upgrade to yet |
| HIGH vulnerability / misconfiguration | warn | pipeline warning, never blocks |
| CRITICAL failed misconfiguration | block | the scan step fails |
| Scanner error (DB download, registry access, parse error) or missing report | **fail** | the result is inconclusive, never treated as clean |

Overrides per run: `blockSeverities` (`CRITICAL` or `CRITICAL,HIGH`), `warnSeverities`,
`useExceptions` (`false` re-evaluates every excepted finding).

## Exceptions

Exceptions are narrow, reviewed and time-bounded. They live in `exceptions.yaml`; each entry has:
finding id, kind (vulnerability or misconfiguration), scope (scan targets such as `image:carts`,
`pkg:carts`, `iac`, or `*`), owner, approver, rationale, created date and expiry date.

- `render_exceptions.py` validates the file on every scan: a missing field, an unknown kind or an
  expiry more than **90 days** after creation fails the scan.
- Only entries whose scope matches the target are applied (Trivy ignore file with `expired_at`).
- An expired exception stops suppressing its finding, so the finding blocks again until it is
  fixed or a new exception is reviewed.
- Suppressed findings are still counted in the report summary ("excepted").

Adding an exception: run the scan, draft entries with `seed_exceptions.py <report dir> --owner …
--approver … --rationale …`, review them, commit them (the commit is the review record).

## Legacy backlog

The Sock Shop images and dependencies date from 2017 and carry a large known backlog. That backlog
is recorded as reviewed exceptions with a 90-day expiry rather than blocking every release, so new
critical findings still block. Remediation (base image and dependency upgrades) is tracked by the
owner; the expiry forces a re-review.
