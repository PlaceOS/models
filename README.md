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

## Control-system changefeed notifications

`ControlSystem` uses pg-orm's model-level changefeed policy to ignore updates confined to `signage_last_seen`, `playlist_item_id`, `name`, `description`, `display_name`, `version`, `updated_at` and the derived `search_vector` column. The automatic `updated_at` and generated search-vector changes are ignored so ordinary metadata saves are also silent. Other search-vector source fields, such as `code`, remain notification-producing. The SQL trigger skips creating a CDC event for these updates while still persisting the values. Changes to other fields, such as `modules`, continue to notify even when the same update changes ignored fields. Inserts and deletes are unchanged.

The policy is installed when the control-system changefeed is registered. It applies to all writers of these fields, and no-op updates on `sys` are also silent. Consumers that need current telemetry or descriptive metadata should query PostgreSQL rather than rely on changefeeds.

Deploy EventBus 1.1.0 or newer to every service that installs CDC triggers before enabling this models version. Older installers can restore the combined trigger and produce unwanted or duplicate update events. pg-orm 2.4.1 or newer passes the model declaration, including explicit database-only columns, to EventBus; no core-side filter is required.

If the earlier two-column policy is already installed, coordinate upgrading all ControlSystem subscribers and explicitly replace that policy before they register the new declaration. Old two-column declarations conflict with the new policy, so avoid overlapping registration by the two versions. From a Crystal process with EventBus loaded and access to the database:

```crystal
EventBus.new(ENV["PG_DATABASE_URL"]).replace_cdc_update_policy(
  "sys",
  ignore_update_columns: ["signage_last_seen", "playlist_item_id", "name", "description", "display_name", "version", "updated_at", "search_vector"],
  expected_ignore_update_columns: ["signage_last_seen", "playlist_item_id"]
)
```

Fresh installations need no replacement. For rollback, use `replace_cdc_update_policy` with the expected current columns; merely removing the model declaration preserves the installed policy.

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
