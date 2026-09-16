# Suppress signage heartbeat changefeed events

Parent issue: https://github.com/PlaceOS/local/issues/146
Agent/task: codex-146-models-20260916-root
Branch: ai/146-signage-heartbeat
Start: 2026-09-16

## Contract

ControlSystem declares `changefeed_ignore_updates :signage_last_seen, :playlist_item_id` using pg-orm 2.4.0 and EventBus 1.1.0. `update_last_seen_time` remains one SQL UPDATE. Telemetry persists (including item changes/clearing) without sys CDC events; updates changing configuration still notify, even if telemetry changes too. INSERT/DELETE and unrelated models retain their notifications. The policy applies to all writers once the changefeed is registered; all trigger-installing services must upgrade before enabling it.

## Checklist

- [x] Verify pg-orm v2.4.0 release, local instructions and uncontested claim.
- [x] Reproduce original bug with real PostgreSQL CDC: first heartbeat produces [insert, update] instead of [insert].
- [x] Require pg-orm >=2.4.0 and remove unversioned override; local ignored lockfile resolves pg-orm2.4.0/EventBus1.1.0.
- [x] Add model-level declaration and explain telemetry intent; single UPDATE unchanged, no migration/core filter.
- [x] Focused regression passes: 2 examples, 0 failures/errors; covers persistence, repeated/nil/empty heartbeat, no CDC rows/notifications, configuration/mixed updates, create/delete and Zone.
- [ ] One agent runs specs at a time; full suite, formatting, lint and GitHub CI must pass.
- [ ] Independent review, squash merge, close parent issue and release claim.

## Review

Independent review approved declaration, dependency requirement, test coverage, rollout docs and behavior-preserving lint cleanup. EventBus/pg-orm stages are already merged/released. No migration is required. Rollout must update all CDC installers before enabling the model policy; SQL-backed telemetry reads remain available. Suppression includes telemetry-only writes outside this method. Record test and CI results in PR and parent issue before completion.

### Verification adjustment

The three-file targeted compile exited 137 before specs ran on the shared 8GB Docker VM. Retry with `--threads 1 --no-debug`; do not stop unrelated user containers or prune Docker. If full local compilation still exceeds available memory, run the full suite on GitHub CI's isolated runner after the focused regression passes.

Focused green: `./test --threads 1 --no-debug spec/control_system_changefeed_spec.cr` passes 2 examples (161ms runtime). Full local suite intentionally deferred to CI after broader three-file compiles hit OOM137 twice. `./bin/ameba`: 180 files, zero failures; formatting/diff checks clean. No local suite remains running.
