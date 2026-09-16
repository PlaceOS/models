# Suppress signage heartbeat changefeed events

Parent issue: https://github.com/PlaceOS/local/issues/146
Agent/task: codex-146-models-20260916-root
Branch: ai/146-signage-heartbeat
Start: 2026-09-16

## Contract

ControlSystem declares `changefeed_ignore_updates :signage_last_seen, :playlist_item_id` using pg-orm 2.4.0 and EventBus 1.1.0. `update_last_seen_time` remains one SQL UPDATE. Telemetry persists (including item changes/clearing) without sys CDC events; updates changing configuration still notify, even if telemetry changes too. INSERT/DELETE and unrelated models retain their notifications. The policy applies to all writers once the changefeed is registered; all trigger-installing services must upgrade before enabling it.

## Checklist

- [x] Verify pg-orm v2.4.0 release, local instructions and uncontested claim.
- [ ] Write failing regression specs against real PostgreSQL CDC before adding the declaration.
- [ ] Update pg-orm minimum version and lockfile, removing its unversioned override.
- [ ] Add model-level declaration and explain telemetry intent; do not add a migration or core filter.
- [ ] Verify timestamp/item persistence, repeated/nil/empty heartbeat, no CDC rows/notifications, ordinary and mixed updates, create/delete and other models.
- [ ] One agent runs specs at a time; full suite, formatting, lint and GitHub CI must pass.
- [ ] Independent review, squash merge, close parent issue and release claim.

## Review

Pending. EventBus/pg-orm stages are already merged/released. No migration is required. Rollout must update all CDC installers before enabling the model policy; SQL-backed telemetry reads remain available. Suppression includes telemetry-only writes outside this method. Record test and CI results in PR and parent issue before completion.
