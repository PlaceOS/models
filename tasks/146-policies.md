# Extend runtime changefeed policies

Parent: https://github.com/PlaceOS/local/issues/146
Owner: codex-146-policies-20260916-root

- [x] Regress Driver name, description, update_available, update_info, compilation_output and updated_at; include generated search_vector exclusion.
- [x] Regress Zone name, description, display_name, playlists, images and updated_at; include generated search_vector exclusion.
- [x] Regress ControlSystem playlists/orientation; retain existing ignored metadata/telemetry/timestamps.
- [x] Preserve relevant and mixed updates, inserts/deletes and an unconfigured model. Inspect ORM callbacks for indirect events.
- [x] Document explicit replacement of existing ControlSystem policy and first registration of new policies.
- [ ] Focused red/green, format/lint, full stable/unstable CI and independent review, then squash merge.

Audit: updated_at is the sole update timestamp. Driver.after_save redundantly saved all associated modules even when copied role/name matched; add a per-module equality guard and regress module notifications as well as Driver events. Core still handles runtime Driver events directly.

Regression red: 23 focused examples, 15 failures and no errors, including requested field updates and indirect Module CDC. Positive runtime changes still pass. Green verification follows declarations and callback guard.

Focused green: 23 specs, zero failures/errors. Formatting/Ameba pass (181 files). Independent source/spec review approved. Driver.module_name and Module.name remain notification-producing, including verified propagation. Full stable/unstable CI pending before squash merge.

User extended active scope: Module ignores updated_at, has_runtime_error and error_timestamp. Add ordinary-save red/green regressions with running modules so error-state callbacks retain values, and positive Module.name/mixed changes. Module.name and Driver.module_name must remain notification-producing. Rerun final CI after this addition; prior CI is superseded.

Module regression red: 27 focused specs, exactly 3 failures for newly ignored fields. Expanded green: all 27 pass, including Module.name and Driver.module_name notification controls. Formatting/lint and independent Module declaration review pass. Final full CI required on expanded scope.
