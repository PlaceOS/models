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
| `RETHINKDB_HOST`          | RethinkDB host                                 | "localhost" |
| `RETHINKDB_PORT`          | RethinkDB port                                 | 28015       |
| `RETHINKDB_DB`            | Database name                                  | "test"      |
| `RETHINKDB_USER`          | Database user                                  | "admin"     |
| `RETHINKDB_PASSWORD`      | Database password                              | ""          |
| `RETHINKDB_TIMEOUT`       | Retry interval in seconds                      | 2           |
| `RETHINKDB_RETRIES`       | Times to reattempt failed driver operations    | 10          |
| `RETHINKDB_QUERY_RETRIES` | Times to reattempt failed queries              | 10          |
| `RETHINKDB_LOCK_EXPIRE`   | Expiry on locks in seconds                     | 30          |
| `RETHINKDB_LOCK_TIMEOUT`  | Timeout on retrying a lock in seconds          | 5           |

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md).
