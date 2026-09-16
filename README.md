# PlaceOS Models

[![CI](https://github.com/PlaceOS/models/actions/workflows/ci.yml/badge.svg)](https://github.com/PlaceOS/models/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/Documentation-available-github.svg)](https://placeos.github.io/models)
[![Changelog](https://img.shields.io/badge/Changelog-available-github.svg)](/CHANGELOG.md)

The database models for [PlaceOS](https://place.technology/) in [crystal](https://crystal-lang.org/).

PlaceOS is a distributed application, with many concurrent event sources that require persistence.
We use [RethinkDB](https://rethinkdb.com) to unify our database and event bus, giving us a consistent interface to state and events across the system.

## Configuration

### Environment

| Key                       | Description                                    | Default     |
| ------------------------- | ---------------------------------------------- | ----------- |
| `PLACE_MAX_VERSIONS`      | Number of versions to keep of versioned models | 20          |
| `PG_HOST`                 | Postgresql host                                | "localhost" |
| `PG_PORT`                 | Postgresql port                                | 5432        |
| `PG_DB`                   | Database name  or `PG_DATABASE`                | "test"      |
| `PG_USER`                 | Database user                                  | "postgres"  |
| `PG_PASSWORD`             | Database password                              | ""          |
| `PG_QUERY`                | Query string, that can be used to configure pooling | ""     |
| `PG_LOCK_TIMEOUT`         | Timeout on retrying Advisory lock in seconds   | 5           |
| `PG_DATABASE_URL`         | Or provide a Database DSN                      |             |

## Runtime changefeed notifications

These models declare the fields that can change without notifying running services:

| Model | Ignored update columns |
| --- | --- |
| `Module` | `updated_at`, `has_runtime_error`, `error_timestamp` |
| `Driver` | `name`, `description`, `update_available`, `update_info`, `compilation_output`, `updated_at`, `search_vector` |
| `Zone` | `name`, `description`, `display_name`, `playlists`, `images`, `updated_at`, `search_vector` |
| `ControlSystem` | `signage_last_seen`, `playlist_item_id`, `name`, `description`, `version`, `updated_at`, `playlists`, `orientation`, `search_vector` |

The SQL trigger skips CDC rows and notifications when an update changes only ignored fields; the values still persist. Automatic `updated_at` and generated `search_vector` changes are included so ordinary metadata saves stay silent. Changes to other columns still notify, even when the same write changes ignored fields. Inserts and deletes are unchanged. Driver saves also skip saving associated modules whose copied name and role already match, preventing redundant module events; `Driver.module_name` and role changes still synchronize associated modules and emit their events. `Driver.module_name`, `Module.name` and `ControlSystem.display_name` are not ignored. Setting or clearing ControlSystem display_name emits an update.

Policies apply to every writer once the model's changefeed is registered. No-op updates on these tables are also silent. Consumers that need current metadata or signage configuration should read PostgreSQL rather than rely on these changefeeds. `created_at` and other unlisted fields remain notification-producing.

Deploy EventBus 1.1.0 or newer to every service that installs CDC triggers before enabling filtering. Older installers can restore the combined trigger and produce unwanted or duplicate events. pg-orm 2.4.1 or newer passes the model declaration, including explicit database-only columns, to EventBus; no core-side filter is required.

Module, Driver and Zone acquire their policies on first registration without a schema migration. For an existing ControlSystem policy, coordinate upgrading its subscribers and explicitly replace the installed policy before they register the new declaration. Old declarations conflict with the new policy, so avoid overlapping registration by the two versions. With the current models loaded, upgrade from the previous ten-column policy using:

```crystal
EventBus.new(ENV["PG_DATABASE_URL"]).replace_cdc_update_policy(
  "sys",
  ignore_update_columns: PlaceOS::Model::ControlSystem.changefeed_ignored_update_columns.not_nil!,
  expected_ignore_update_columns: ["signage_last_seen", "playlist_item_id", "name", "description", "display_name", "version", "updated_at", "playlists", "orientation", "search_vector"]
)
```

For the earlier eight-column policy, omit `playlists` and `orientation` from the expected list. If only the original two-column policy was installed, use `["signage_last_seen", "playlist_item_id"]` as the expected list instead. Fresh installations need no replacement. Do not guess the installed policy or suppress a mismatch error. For rollback, use `replace_cdc_update_policy` with the expected current columns; merely removing a declaration preserves the installed policy.

## Testing

```shell
# prune docker images if you have new migrations that need to run
# since the last time migrations image was built
docker system prune --all

# builds migrations and runs tests in a containerised env
./test
```

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md).
