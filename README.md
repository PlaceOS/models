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
