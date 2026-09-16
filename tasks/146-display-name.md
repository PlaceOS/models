# Restore ControlSystem display_name events

Issue: https://github.com/PlaceOS/local/issues/146
Owner: codex-146-display-name-20260916-root

- [ ] Regress setting and clearing display_name via save! emits PG notifications and CDC rows.
- [ ] Remove only ControlSystem display_name exclusion; retain remaining policies and suppression regressions.
- [ ] Update documented installed-policy replacement from previous ten-column policy.
- [ ] Focused red/green, lint/format, full stable/unstable CI and review, then squash merge.
