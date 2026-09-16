# ControlSystem metadata changefeed exclusion

Issue: https://github.com/PlaceOS/local/issues/146
Owner: codex-146-metadata-20260916-root

- [x] Regress ordinary saves of each of name, description, display_name and version: persisted with no CDC row or PG notification.
- [x] Retain heartbeat coverage and prove modules-only and mixed modules/metadata updates notify, plus insert/delete and Zone.
- [x] Extend model declaration, including automatic updated_at bookkeeping; document explicit transition from installed two-column policy.
- [ ] Run focused regression, formatting/lint, full stable/unstable CI; independent review then squash merge.

Replan from regression: original policy fails all four metadata save cases. Adding updated_at plus requested fields still fails name/description/display_name because PostgreSQL regenerates unmapped search_vector. Add explicit database_columns in pg-orm PR22 before final models adoption. Do not map fake application attributes for database-derived values. Add code-only positive coverage because it is another search_vector source. Models completion gated on released pg-orm support.

Final focused green: 6 specs, zero failures/errors against pg-orm PR22. Original regression red all four metadata cases; intermediate red three generated-search-vector cases. Formatting/Ameba pass. pg-orm PR22 merged with 488 specs and CI green. Models uses temporary exact merged commit override for full CI; replace with released minimum and remove override before merge.
