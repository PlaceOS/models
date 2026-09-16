# ControlSystem metadata changefeed exclusion

Issue: https://github.com/PlaceOS/local/issues/146
Owner: codex-146-metadata-20260916-root

- [ ] Regress each of name, description, display_name and version: persisted with no CDC row or PG notification.
- [ ] Retain heartbeat coverage and prove modules-only and mixed modules/metadata updates notify, plus insert/delete and Zone.
- [ ] Extend model declaration; document explicit transition from installed two-column policy.
- [ ] Run focused regression, formatting/lint, full stable/unstable CI; independent review then squash merge.
