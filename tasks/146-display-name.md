# Restore ControlSystem display_name events

Issue: https://github.com/PlaceOS/local/issues/146
Owner: codex-146-display-name-20260916-root

- [x] Regress setting and clearing display_name via save! emits PG notifications and CDC rows.
- [x] Remove only ControlSystem display_name exclusion; retain remaining policies and suppression regressions.
- [x] Update documented installed-policy replacement from previous ten-column policy.
- [ ] Focused red/green, lint/format, full stable/unstable CI and review, then squash merge.

Regression red: 6 specs, one failure, expected update CDC row absent on display_name save. Removed only the ControlSystem exclusion. Formatting/Ameba pass (181 files); focused green and full CI required before merge. Docs/spec review approved.
