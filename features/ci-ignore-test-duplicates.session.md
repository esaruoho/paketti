# Ignore test fixtures in CI duplicate checks

User request: “it should ignore duplicate function entries / menu entries that spawn from tests/ folder. since those are never run when Paketti is loaded.”

The registration harness already loads main.lua through its actual startup path. The recursive Python static scans included test Lua files. Added a shared source-file selector excluding directory components .git, .spine, and tests, and used it for duplicate globals and undeclared-call scans. The workflow comment explains the scope. No runtime menu registrations were changed.

Verification: temporary fixtures showed that copied helpers in tests/, nested tests/, and modules/tests/ are ignored, real source duplicates still return both locations, and contest.lua remains scanned. Full registration gate results are recorded below after execution.

## How to get back

Current transcript path, session ID, and transcript timestamps could not be confirmed from the exposed session context; no resume ID or transcript bundle is fabricated. This file records the visible request and implementation rationale. No commit, push, or PR was requested or performed.

Card: [ci-ignore-test-duplicates.feature](ci-ignore-test-duplicates.feature).

Full local gate: python3 .spine/check.py . exited 0: no duplicate registrations or brittle files. Existing advisory warnings remain.
