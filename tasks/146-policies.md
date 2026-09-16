# Extend runtime changefeed policies

Parent: https://github.com/PlaceOS/local/issues/146
Owner: codex-146-policies-20260916-root

- [ ] Regress Driver name, description, update_available, update_info, compilation_output and updated_at; include generated search_vector exclusion.
- [ ] Regress Zone name, description, display_name, playlists, images and updated_at; include generated search_vector exclusion.
- [ ] Regress ControlSystem playlists/orientation; retain existing ignored metadata/telemetry/timestamps.
- [ ] Preserve relevant and mixed updates, inserts/deletes and an unconfigured model. Inspect ORM callbacks for indirect events.
- [ ] Document explicit replacement of existing ControlSystem policy and first registration of new policies.
- [ ] Focused red/green, format/lint, full stable/unstable CI and independent review, then squash merge.
