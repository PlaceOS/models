## v9.76.0 (2025-09-23)

### Feat

- [PPT-2176] Added schema and respective model attributes ([#295](https://github.com/PlaceOS/models/pull/295))

## v9.75.2 (2025-09-23)

### Refactor

- **booking_recurring_spec**: [PPT-1993] Added more tests to validate logic ([#292](https://github.com/PlaceOS/models/pull/292))

## v9.75.1 (2025-09-18)

### Refactor

- **alert**: marked fields to be indexable in ES ([#297](https://github.com/PlaceOS/models/pull/297))

## v9.75.0 (2025-09-17)

### Feat

- [PPT-2077] Added alert & dashboard models ([#296](https://github.com/PlaceOS/models/pull/296))

## v9.74.0 (2025-09-08)

### Feat

- **outlook-manifest**: [PPT-2078] remove default Microsoft login domain from app domains ([#294](https://github.com/PlaceOS/models/pull/294))

## v9.73.0 (2025-09-01)

### Feat

- [PPT-2172] Added root_path to repo model ([#293](https://github.com/PlaceOS/models/pull/293))

## v9.72.4 (2025-08-05)

### Fix

- **playlist**: removal of cron via API

## v9.72.3 (2025-08-04)

### Fix

- bump version

## v9.72.2 (2025-07-22)

### Fix

- **signage/revision**: user_id is nullable

## v9.72.1 (2025-07-22)

### Fix

- **signage/revision**: protect some fields

## v9.72.0 (2025-07-21)

### Feat

- **signage**: add approval support

## v9.71.1 (2025-07-21)

### Fix

- **signage**: playlist filtering using orientation

## v9.71.0 (2025-07-13)

### Feat

- **module**: add analytics configuration fields ([#291](https://github.com/PlaceOS/models/pull/291))

## v9.70.0 (2025-06-24)

### Feat

- **user**: add logged_out_at flag

## v9.69.0 (2025-06-16)

### Feat

- **upload**: add cache helpers

## v9.68.0 (2025-06-16)

## v9.67.0 (2025-06-10)

### Feat

- **storage**: add default storage flag ([#288](https://github.com/PlaceOS/models/pull/288))

## v9.66.0 (2025-06-06)

### Feat

- user photo upload and locatable flag [PPT-2038] ([#287](https://github.com/PlaceOS/models/pull/287))

## v9.65.3 (2025-06-06)

### Fix

- **booking.cr**: PPT-2007 properly handle overlapping bookings ([#286](https://github.com/PlaceOS/models/pull/286))

## v9.65.2 (2025-05-22)

### Fix

- **edge**: type for timestamp in openapi docs

## v9.65.1 (2025-04-16)

## v9.65.0 (2025-04-14)

### Feat

- **control_system**: [PPT-2004] add approval column ([#285](https://github.com/PlaceOS/models/pull/285))

## v9.64.1 (2025-04-07)

## v9.64.0 (2025-02-21)

### Feat

- **bookings**: [PPT-1781] ignore clash check forvisitor booking ([#284](https://github.com/PlaceOS/models/pull/284))

## v9.63.0 (2025-02-19)

### Feat

- **bookings**: [PPT-1846] add all_day bool flag ([#283](https://github.com/PlaceOS/models/pull/283))

## v9.62.4 (2025-02-13)

### Fix

- **settings**: validate yaml to json conversion [PPT-1873] ([#282](https://github.com/PlaceOS/models/pull/282))

## v9.62.3 (2025-01-29)

### Fix

- **booking**: correct start and end times in instance

## v9.62.2 (2025-01-21)

### Fix

- **tenant**: parent_id helpers

## v9.62.1 (2025-01-21)

### Fix

- **asset_type**: images is nilable in the database ([#281](https://github.com/PlaceOS/models/pull/281))

## v9.62.0 (2025-01-21)

### Feat

- **tenant**: delegate tenant configuration ([#280](https://github.com/PlaceOS/models/pull/280))

## v9.61.1 (2025-01-13)

### Fix

- **bookings**: prefix checked_in with bookings in sql ([#279](https://github.com/PlaceOS/models/pull/279))

## v9.61.0 (2024-12-31)

### Feat

- PPT-54 Add full text search capabilities to guest model ([#278](https://github.com/PlaceOS/models/pull/278))

## v9.60.1 (2024-11-27)

### Fix

- **bookings**: booking_recurrences may not be filled

## v9.60.0 (2024-10-24)

### Feat

- PPT-1622 Add auth tokens cleanup code ([#277](https://github.com/PlaceOS/models/pull/277))

## v9.59.1 (2024-10-15)

### Fix

- **booking**: recurring booking clash check ([#276](https://github.com/PlaceOS/models/pull/276))

## v9.59.0 (2024-09-05)

### Feat

- PPT-642 Added place_id attribute in zone model ([#275](https://github.com/PlaceOS/models/pull/275))

## v9.58.3 (2024-09-03)

### Fix

- **booking**: provide a helper for filtering checked in/out instances

## v9.58.2 (2024-09-03)

### Fix

- **booking**: fix is_checked_in query

## v9.58.1 (2024-08-30)

### Fix

- **Booking**: clashing should not inspect checked out bookings

## v9.58.0 (2024-08-29)

### Feat

- **user**: [PPT-1484] format of work_preferences and work_overrides ([#274](https://github.com/PlaceOS/models/pull/274))

## v9.57.6 (2024-08-21)

## v9.57.5 (2024-08-19)

### Fix

- **playlist**: make 0 the default playlist animation

## v9.57.4 (2024-08-19)

### Fix

- **control_system**: include playlist updated at in cache bust

## v9.57.3 (2024-08-19)

### Fix

- **playlist/item**: update playlists when an item is changed

## v9.57.2 (2024-08-19)

### Fix

- **control_system**: playlists_last_updated using created at

## v9.57.1 (2024-08-16)

### Fix

- **playlist/item**: update playlists when media is deleted

## v9.57.0 (2024-08-15)

### Feat

- PPT-1475 mark Trigger fields to ignore from ES index ([#273](https://github.com/PlaceOS/models/pull/273))

## v9.56.6 (2024-08-14)

### Refactor

- **booking**: change induction to an enum ([#272](https://github.com/PlaceOS/models/pull/272))

## v9.56.5 (2024-08-13)

### Fix

- **booking**: prevent save if instance is set

## v9.56.4 (2024-08-12)

### Fix

- **playlist**: valid from and until field types

## v9.56.3 (2024-08-06)

### Fix

- **authority**: Add migration script to set defaults ([#271](https://github.com/PlaceOS/models/pull/271))

## v9.56.2 (2024-08-05)

### Fix

- **authority**: email_domains should handle nilable

## v9.56.1 (2024-08-05)

### Fix

- **migrations**: add default to email_domains

## v9.56.0 (2024-08-05)

### Feat

- **playlist/item**: add video length ([#270](https://github.com/PlaceOS/models/pull/270))

## v9.55.0 (2024-08-05)

### Feat

- PPT-1470 Add email domain feature to Authority model ([#269](https://github.com/PlaceOS/models/pull/269))

## v9.54.0 (2024-07-31)

### Feat

- **booking**: [PPT-1405] update approved/rejected fields on child bookings ([#267](https://github.com/PlaceOS/models/pull/267))

## v9.53.3 (2024-07-16)

### Fix

- crystal 1.13 scope issue

## v9.53.2 (2024-07-16)

### Fix

- **base/associations**: macro type resolution error

## v9.53.1 (2024-07-15)

### Fix

- remove openapi-generator

## v9.53.0 (2024-07-12)

### Feat

- **event_metadata**: add permission field ([#266](https://github.com/PlaceOS/models/pull/266))

## v9.52.1 (2024-07-11)

### Fix

- **booking**: add timezone validation

## v9.52.0 (2024-07-11)

### Feat

- PPT-1437 Add early_check field to Tenant model ([#265](https://github.com/PlaceOS/models/pull/265))

## v9.51.1 (2024-07-09)

### Fix

- **booking**: ensure clash check is appropriately scoped

## v9.51.0 (2024-07-09)

### Feat

- **booking**: add helpers for paginating recurrences

## v9.50.0 (2024-07-05)

### Feat

- **bookings**: transparent booking instance modification

## v9.49.0 (2024-07-04)

### Feat

- **bookings**: add recurring support to bookings ([#263](https://github.com/PlaceOS/models/pull/263))

## v9.48.0 (2024-06-21)

### Feat

- PPT-1413 Add error flag to Repository model ([#264](https://github.com/PlaceOS/models/pull/264))

## v9.47.1 (2024-06-03)

### Fix

- **module**: make error indicator fields as read-only ([#262](https://github.com/PlaceOS/models/pull/262))

## v9.47.0 (2024-05-16)

### Feat

- PPT-1321 Update module model ([#260](https://github.com/PlaceOS/models/pull/260))

## v9.46.0 (2024-05-15)

### Feat

- **booking**: #by_user_or_email include open and public permissions ([#261](https://github.com/PlaceOS/models/pull/261))

## v9.45.0 (2024-03-27)

### Feat

- **booking**: [PPT-1267] add induction field ([#259](https://github.com/PlaceOS/models/pull/259))

## v9.44.1 (2024-03-21)

### Fix

- **shortener**: add some rand and validation

## v9.44.0 (2024-03-21)

### Feat

- **shortener**: add URL shortening model ([#258](https://github.com/PlaceOS/models/pull/258)) [PPT-1272]

## v9.43.0 (2024-03-20)

### Feat

- **booking**: [PPT-1215] add permission field ([#256](https://github.com/PlaceOS/models/pull/256))

## v9.42.2 (2024-03-19)

### Fix

- **driver**: remove flag if commits match ([#257](https://github.com/PlaceOS/models/pull/257))

## v9.42.1 (2024-03-13)

### Fix

- **migrations**: signage migration

## v9.42.0 (2024-03-11)

### Feat

- **playlist**: add helpers for updating metrics

## v9.41.1 (2024-03-09)

### Fix

- **playlist/item**: requires authority scope

## v9.41.0 (2024-03-08)

### Feat

- add digital signage models ([#255](https://github.com/PlaceOS/models/pull/255)) [PPT-1040]

## v9.40.0 (2024-03-06)

### Feat

- **booking**: [PPT-1213] add images ([#254](https://github.com/PlaceOS/models/pull/254))

## v9.39.1 (2024-03-01)

### Fix

- **booking**: can't clash if deleted

## v9.39.0 (2024-02-29)

### Feat

- PPT-1224 Add secret_expiry attribute to tenant model ([#253](https://github.com/PlaceOS/models/pull/253))

## v9.38.2 (2024-02-29)

### Fix

- **bookings**: prevent start and end times being the same

## v9.38.1 (2024-02-29)

### Fix

- **booking**: expose format_list_for_postgres

## v9.38.0 (2024-02-29)

### Feat

- **bookings**: split out unique ids

## v9.37.6 (2024-02-29)

### Fix

- **bookings**: details specs for desired behaviour [PROJ-636] ([#252](https://github.com/PlaceOS/models/pull/252))

## v9.37.5 (2024-02-28)

### Fix

- **bookings**: improve update_assets

## v9.37.4 (2024-02-22)

### Fix

- **booking**: ensure all asset ids are unique in the booking

## v9.37.3 (2024-02-21)

### Fix

- **survey**: make Survey::Invitation.list(sent: false) return unsent invites ([#251](https://github.com/PlaceOS/models/pull/251))

## v9.37.2 (2024-02-15)

### Fix

- **booking**: #clashing? with asset_ids ([#250](https://github.com/PlaceOS/models/pull/250))

## v9.37.1 (2024-02-14)

### Refactor

- **zone**: [PPT-1154] remove unused field ([#248](https://github.com/PlaceOS/models/pull/248))

## v9.37.0 (2024-02-07)

### Feat

- **zone**: [PPT-1154] add auto_release ([#247](https://github.com/PlaceOS/models/pull/247))

## v9.36.4 (2024-01-30)

### Fix

- **model**: DBHashConverter ([#246](https://github.com/PlaceOS/models/pull/246))

## v9.36.3 (2024-01-30)

### Fix

- **user**: change WorktimePreference day to day_of_week ([#245](https://github.com/PlaceOS/models/pull/245))

## v9.36.2 (2024-01-25)

### Fix

- **users**: [PPT-1148] work_preferences default ([#244](https://github.com/PlaceOS/models/pull/244))

## v9.36.1 (2024-01-24)

### Fix

- **user**: work_preferences need to be public

## v9.36.0 (2024-01-24)

### Feat

- **wfh**: [PPT-1148] add work_preferences to user model ([#243](https://github.com/PlaceOS/models/pull/243))

## v9.35.7 (2023-12-22)

## v9.35.6 (2023-12-21)

### Fix

- **guest**: don't pick a meeting that has ended

## v9.35.5 (2023-12-21)

### Fix

- **guest**: checked_in is never null

## v9.35.4 (2023-12-21)

### Fix

- **guest**: order by the earliest starting booking

## v9.35.3 (2023-12-21)

### Fix

- **guest**: need to ensure the joins have a result

## v9.35.2 (2023-12-21)

### Fix

- **guest**: attending today query

## v9.35.1 (2023-12-18)

### Fix

- **event_metadata**: metadata migration

## v9.35.0 (2023-12-18)

### Feat

- **event_metadata**: add an additional query

## v9.34.0 (2023-12-18)

### Feat

- **event_metadata**: allows lookup of recurring master events ([#241](https://github.com/PlaceOS/models/pull/241)) [PPT-1072]

## v9.33.2 (2023-12-13)

### Fix

- **guest**: remove property overload

## v9.33.1 (2023-12-13)

### Fix

- **bookings**: remove ambiguity on extension_data

## v9.33.0 (2023-12-12)

### Feat

- **bookings**: checked in status on booking guests ([#240](https://github.com/PlaceOS/models/pull/240))

## v9.32.0 (2023-12-12)

### Feat

- **event_metadata**: include guest list in linked bookings

## v9.31.0 (2023-12-12)

### Feat

- PPT-1113 add collection serialization logic ([#239](https://github.com/PlaceOS/models/pull/239))

## v9.30.1 (2023-12-06)

### Fix

- **control_system**: should only remove modules only in system [PPT-1102] ([#238](https://github.com/PlaceOS/models/pull/238))

## v9.30.0 (2023-12-06)

### Feat

- PPT-1098 Add support of multiple assets per booking ([#237](https://github.com/PlaceOS/models/pull/237))

## v9.29.0 (2023-12-04)

### Feat

- PPT-1077 add user login stats ([#236](https://github.com/PlaceOS/models/pull/236))

## v9.28.0 (2023-11-28)

### Feat

- PPT-1085 Add OpenAI Tool Call support ([#235](https://github.com/PlaceOS/models/pull/235))

## v9.27.0 (2023-11-14)

### Feat

- PPT-1038 Driver update required logic ([#234](https://github.com/PlaceOS/models/pull/234))

## v9.26.0 (2023-11-02)

### Feat

- **chat_message**: track token usage

## v9.25.2 (2023-10-25)

### Fix

- migration order due to commit merge

## v9.25.1 (2023-10-25)

### Fix

- **event_metadata**: change setup_event_id and breakdown_event_id data type in DB ([#233](https://github.com/PlaceOS/models/pull/233))

## v9.25.0 (2023-10-13)

### Feat

- PPT-568 Added Models for ChatBot ([#232](https://github.com/PlaceOS/models/pull/232))

## v9.24.1 (2023-10-06)

### Fix

- **attendee**: resolve compile issue

## v9.24.0 (2023-10-06)

### Feat

- **attendee**: ensure booking checked in if guest is ([#230](https://github.com/PlaceOS/models/pull/230))

## v9.23.0 (2023-10-04)

### Feat

- **event_metadata**: add setup/breakdown time ([#229](https://github.com/PlaceOS/models/pull/229))

## v9.22.0 (2023-09-25)

### Feat

- **migrations**: move id indexes to hash indexes

## v9.21.0 (2023-09-25)

### Feat

- **migrations**: add index on bookings parent_id

## v9.20.1 (2023-09-21)

### Fix

- **booking**: check for clashing in a transaction PPT-931 ([#228](https://github.com/PlaceOS/models/pull/228))

## v9.20.0 (2023-09-12)

### Feat

- PPT-864 Added fields to capture online and last seen activity ([#227](https://github.com/PlaceOS/models/pull/227))

## v9.19.0 (2023-09-12)

### Feat

- **event_metadata**: render rejected bookings

## v9.18.8 (2023-09-08)

### Fix

- **api_key**: allow string or integer for setting permissions

## v9.18.7 (2023-09-08)

### Fix

- **api_key**: allow field to be nillable

## v9.18.6 (2023-09-08)

### Fix

- **api_key**: public json to return permissions as a string

## v9.18.5 (2023-09-08)

### Fix

- **api_key**: deal with nil values in the database

## v9.18.4 (2023-09-08)

### Fix

- **api_key**: allow permissions to be nil

## v9.18.3 (2023-09-08)

### Fix

- **api_key**: default permissions to be user

## v9.18.2 (2023-09-08)

### Fix

- **Enum::ValueConverter**: support nilable integer enums

## v9.18.1 (2023-09-07)

### Fix

- **api_key**: permissions are stored as an integer in the database

## v9.18.0 (2023-09-07)

### Feat

- **upload**: ensures upload file names are valid across systems ([#226](https://github.com/PlaceOS/models/pull/226))

## v9.17.3 (2023-09-05)

### Fix

- **storage**: fix mime types getting overwritten issue ([#224](https://github.com/PlaceOS/models/pull/224))

## v9.17.2 (2023-08-29)

### Fix

- **storage**: clean extension prior to filter

## v9.17.1 (2023-08-23)

## v9.17.0 (2023-08-21)

### Feat

- **storage**: Added file extension and mime filter attributes ([#223](https://github.com/PlaceOS/models/pull/223))

## v9.16.3 (2023-08-17)

### Fix

- **survey**: make Survey::Invitation.list return unsent invites if their sent state is null in the DB and sent = false is passed to the function ([#222](https://github.com/PlaceOS/models/pull/222))

## v9.16.2 (2023-08-17)

### Fix

- **control_system**: reject invalid module ids at save ([#221](https://github.com/PlaceOS/models/pull/221))

## v9.16.1 (2023-08-15)

### Fix

- **zone**: find root zone id without being persisted ([#220](https://github.com/PlaceOS/models/pull/220))

## v9.16.0 (2023-08-14)

### Feat

- PPT-767 File Upload models for Storage and Upload ([#219](https://github.com/PlaceOS/models/pull/219))

## v9.15.1 (2023-08-14)

### Fix

- Add skip_authorization field to the Doorkeeper ([#218](https://github.com/PlaceOS/models/pull/218))

## v9.15.0 (2023-08-02)

### Feat

- **zone**: add root zone finding helper

### Fix

- **guest**: attending check

## v9.14.3 (2023-07-26)

### Fix

- **PPT-729**: Add missing FK cascade delete to FKs ([#217](https://github.com/PlaceOS/models/pull/217))

## v9.14.2 (2023-07-10)

### Fix

- **migrations**: added pgsql as language for PG func

## v9.14.1 (2023-07-10)

### Fix

- **migrations**: multi-line statement, updated spec PG version to 15

## v9.14.0 (2023-07-07)

### Feat

- **migrations**: PPT-53 add index on metadata details

## v9.13.4 (2023-07-06)

### Fix

- **migrations**: ensure unique_domain constraint does not exist

## v9.13.3 (2023-07-05)

### Fix

- tenants_domain migration

## v9.13.2 (2023-07-05)

### Fix

- **migrations**: ensure unique constraint removed

## v9.13.1 (2023-07-05)

### Fix

- **tenant**: email_domain should be set on create / update

## v9.13.0 (2023-06-29)

### Feat

- **asset_type**: include asset counts in responses ([#215](https://github.com/PlaceOS/models/pull/215))

## v9.12.0 (2023-06-25)

### Feat

- **asset**: add barcode field ([#212](https://github.com/PlaceOS/models/pull/212))

## v9.11.3 (2023-06-24)

### Refactor

- EpochConverter#from_json

## v9.11.2 (2023-06-14)

### Fix

- **migrations**: added checks

## v9.11.1 (2023-06-13)

### Fix

- **module**: edge_id lookup query

## v9.11.0 (2023-06-13)

### Feat

- **tenant**: add multi-tenant per domain support ([#213](https://github.com/PlaceOS/models/pull/213))
- **migrations**: PPT-431, 432 additional indices ([#211](https://github.com/PlaceOS/models/pull/211))

## v9.10.2 (2023-06-05)

### Fix

- **event_metadata**: linked bookings spec

## v9.10.1 (2023-06-05)

### Fix

- **event_metadata**: add flag for rendering linked bookings

## v9.10.0 (2023-06-05)

### Feat

- link assets to zones and clean up bookings ([#210](https://github.com/PlaceOS/models/pull/210))

## v9.9.2 (2023-06-01)

### Fix

- **booking**: linked? inverted

## v9.9.1 (2023-05-31)

### Fix

- **booking**: add is_booking_type scope

## v9.9.0 (2023-05-31)

### Feat

- link bookings to events ([#209](https://github.com/PlaceOS/models/pull/209))

## v9.8.0 (2023-05-24)

### Feat

- **asset_manager**: change ids to strings ([#208](https://github.com/PlaceOS/models/pull/208))

## v9.7.1 (2023-05-23)

### Fix

- **user**: update cleanup_auth_tokens with updated relations name

## v9.7.0 (2023-05-22)

### Feat

- **asset**: [PPT-334] elastic search index ([#207](https://github.com/PlaceOS/models/pull/207))

## v9.6.0 (2023-05-19)

### Feat

- **staff-api**: PPT-387 staff api implement linked bookings child parent relationship ([#205](https://github.com/PlaceOS/models/pull/205))

## v9.5.0 (2023-05-19)

### Feat

- **asset**: new asset manager models ([#204](https://github.com/PlaceOS/models/pull/204))

## v9.4.1 (2023-05-16)

### Fix

- **migrations**: incorrect trigger table name

## v9.4.0 (2023-05-10)

### Feat

- **migrations**: Sync migrations from init

## v9.3.1 (2023-05-10)

### Fix

- **associations**: serialize should default to true

## v9.3.0 (2023-05-10)

### Feat

- **migrations**: add db level constraints to trig table ([#203](https://github.com/PlaceOS/models/pull/203))

## v9.2.0 (2023-05-03)

### Refactor

- added models for staff-api ([#201](https://github.com/PlaceOS/models/pull/201))

## v9.1.0 (2023-04-21)

### Feat

- **control_system**: remove feature auto-population PPT-392 ([#202](https://github.com/PlaceOS/models/pull/202))

## v9.0.4 (2023-04-19)

### Feat

- **user_jwt**: always ensure email is downcased

## v9.0.3 (2023-04-18)

### Feat

- added to_rs method and support for dealing with nilable value in EnumConverter ([#200](https://github.com/PlaceOS/models/pull/200))

## v9.0.2 (2023-03-21)

### Fix

- **base/jwt**: generate public key from private ([#199](https://github.com/PlaceOS/models/pull/199))

## v9.0.1 (2023-03-17)

### Fix

- **user**: adjust optional fields

## v9.0.0 (2023-03-16)

### Fix

- merge commit fb436e breaks asset and asset_instance ([#198](https://github.com/PlaceOS/models/pull/198))

### Refactor

- migrate models to postgres via pg-orm ([#188](https://github.com/PlaceOS/models/pull/188))

## v8.13.4 (2023-03-09)

## v8.13.3 (2023-02-24)

### Feat

- **control_system**: add public flag ([#196](https://github.com/PlaceOS/models/pull/196))

## v8.13.2 (2023-02-06)

### Feat

- **user**: expose email and phone number ([#195](https://github.com/PlaceOS/models/pull/195))

## v8.13.1 (2022-12-14)

### Fix

- **asset**: time fields should be unix epochs at the API level ([#194](https://github.com/PlaceOS/models/pull/194))

## v8.13.0 (2022-12-05)

### Feat

- **zone**: add images ([#192](https://github.com/PlaceOS/models/pull/192))
- **zone**: add timezone ([#191](https://github.com/PlaceOS/models/pull/191))

## v8.12.2 (2022-10-27)

### Fix

- docker-compose file entry for shard.yml.input ([#187](https://github.com/PlaceOS/models/pull/187))

## v8.12.1 (2022-10-25)

### Fix

- **email**: store emails downcased for simplified querying ([#186](https://github.com/PlaceOS/models/pull/186))

## v8.12.0 (2022-08-12)

### Feat

- **module**: `resolved_name_changed?`

## v8.11.3 (2022-08-09)

### Feat

- **user**: user metadata should be available to authenticated users ([#181](https://github.com/PlaceOS/models/pull/181))

## v8.11.2 (2022-07-06)

## v8.11.1 (2022-07-05)

## v8.11.0 (2022-06-23)

### Perf

- **metadata**: remove queries and optimize uniqueness check ([#180](https://github.com/PlaceOS/models/pull/180))

## v8.10.0 (2022-06-23)

### Feat

- **user**: add admin_metadata json output ([#179](https://github.com/PlaceOS/models/pull/179))

### Refactor

- extracted json-merge-patch to a shard

## v8.9.2 (2022-06-01)

### Fix

- **executable**: short commit ([#177](https://github.com/PlaceOS/models/pull/177))

## v8.9.1 (2022-05-30)

### Fix

- **executable**: pull in `error`

## v8.9.0 (2022-05-30)

### Feat

- add `PlaceOS::Model::Executable`

## v8.8.1 (2022-05-16)

### Fix

- **repository**: pull! should use deployed_commit_hash ([#176](https://github.com/PlaceOS/models/pull/176))

## v8.8.0 (2022-05-16)

### Feat

- **repository**: add deployed_commit_hash ([#175](https://github.com/PlaceOS/models/pull/175))

## v8.7.0 (2022-05-06)

### Feat

- **metadata**: add `Metadata.query_count`

## v8.6.0 (2022-05-06)

### Feat

- **metadata**: add pagination ([#174](https://github.com/PlaceOS/models/pull/174))

## v8.5.0 (2022-05-05)

### Feat

- **edge**: add `#to_key_json` ([#173](https://github.com/PlaceOS/models/pull/173))

## v8.4.1 (2022-05-04)

### Fix

- **edge**: optional `user_id` in create interface

## v8.4.0 (2022-05-02)

### Feat

- **metadata**: expose merge in `assign_from_interface`

## v8.3.0 (2022-05-02)

### Feat

- `Metadata#details` merge ([#172](https://github.com/PlaceOS/models/pull/172))

## v8.2.9 (2022-04-26)

### Feat

- **user**: expose `staff_id` ([#171](https://github.com/PlaceOS/models/pull/171))

## v8.2.8 (2022-04-22)

### Fix

- **generator**: typo in the generator

## v8.2.7 (2022-04-22)

### Fix

- **spec/generator**: remove call to `inspect_error`

## v8.2.6 (2022-04-22)

### Fix

- **metadata#query**: allow `@` and ` ` in keys and values ([#170](https://github.com/PlaceOS/models/pull/170))

## v8.2.5 (2022-04-22)

### Fix

- **last_modified**: prevent assignment of `modified_by_id`

## v8.2.4 (2022-04-22)

### Fix

- **last_modified**: ensure `modified_by_id` is serialised ([#169](https://github.com/PlaceOS/models/pull/169))

## v8.2.3 (2022-04-21)

### Fix

- **User#find_by_email**: digest was not used ([#168](https://github.com/PlaceOS/models/pull/168))

## v8.2.2 (2022-04-14)

### Fix

- **metadata**: `parent_id` could be nil

## v8.2.1 (2022-04-14)

### Perf

- **metadata**: faster name queries

## v8.2.0 (2022-04-13)

### Feat

- **metadata**: add `to_parent_json` ([#166](https://github.com/PlaceOS/models/pull/166))
- **metadata#query**: add ability to filter by name ([#167](https://github.com/PlaceOS/models/pull/167))

## v8.1.0 (2022-04-07)

### Feat

- **metadata**: implement queries ([#164](https://github.com/PlaceOS/models/pull/164))

## v8.0.0 (2022-04-07)

## v7.6.7 (2022-03-24)

### Fix

- **version**: missing import

## v7.6.6 (2022-03-23)

### Fix

- **last_modified**: skip warn for versions

## v7.6.5 (2022-03-23)

### Fix

- **metadata**: skip parent validation if no `parent_id` ([#162](https://github.com/PlaceOS/models/pull/162))

## v7.6.4 (2022-03-22)

### Fix

- **metadata**: typo

## v7.6.3 (2022-03-22)

### Fix

- **Metadata.user_can_create?**: looser `parent_id` restriction ([#161](https://github.com/PlaceOS/models/pull/161))

## v7.6.2 (2022-03-22)

### Refactor

- **metadata**: creation/update helpers ([#160](https://github.com/PlaceOS/models/pull/160))

## v7.6.1 (2022-03-21)

### Fix

- resolve a missing symbol

## v7.6.0 (2022-03-21)

### Feat

- **model**: produce model schema ([#158](https://github.com/PlaceOS/models/pull/158))

## v7.5.0 (2022-03-21)

### Feat

- **metadata**: add `Metadata.build_history` ([#159](https://github.com/PlaceOS/models/pull/159))

## v7.4.0 (2022-03-21)

### Feat

- **metadata**: add `id` to `Metadata::Interface` ([#157](https://github.com/PlaceOS/models/pull/157))

## v7.3.0 (2022-03-18)

### Feat

- **versions**: add `#history_count`

## v7.2.0 (2022-03-17)

### Feat

- **metadata**: validate parent exists ([#155](https://github.com/PlaceOS/models/pull/155))

## v7.1.1 (2022-03-17)

### Fix

- **versions#history**: restore `offset` and `limit` ([#154](https://github.com/PlaceOS/models/pull/154))

## v7.1.0 (2022-03-10)

### Feat

- **metadata**: add `#history` ([#153](https://github.com/PlaceOS/models/pull/153))

## v7.0.0 (2022-03-09)


- update active-model and rethinkdb-orm ([#152](https://github.com/PlaceOS/models/pull/152))

## v6.7.0 (2022-03-08)

### Feat

- add `modified_at` and `modified_by` to Settings and Metadata ([#148](https://github.com/PlaceOS/models/pull/148))

## v6.6.6 (2022-03-07)

### Refactor

- change path of converters ([#149](https://github.com/PlaceOS/models/pull/149))

## v6.6.5 (2022-03-01)

### Fix

- scope errors, add missing require

## v6.6.4 (2022-03-01)

### Fix

- **api_key**: no error if SaaS key already exists, add `public` scope to key ([#147](https://github.com/PlaceOS/models/pull/147))

## v6.6.3 (2022-02-23)

### Fix

- **edges**: pass `user_id` in create

## v6.6.2 (2022-02-23)

### Fix

- **edge**: add `user_id` to `CreateBody`

## v6.6.1 (2022-02-22)

### Fix

- **edge**: save ApiKey in create callback

## v6.6.0 (2022-02-22)

### Refactor

- **edge**: move key clean-up to `save!` ([#145](https://github.com/PlaceOS/models/pull/145))

## v6.5.0 (2022-02-18)

### Feat

- **edge**: add edge-control scope ([#143](https://github.com/PlaceOS/models/pull/143))

## v6.4.0 (2022-02-18)

### Refactor

- edge api key ([#141](https://github.com/PlaceOS/models/pull/141))

## v6.3.0 (2022-02-10)

### Feat

- add openapi-serializable ([#142](https://github.com/PlaceOS/models/pull/142))

## v6.2.0 (2022-02-04)

### Refactor

- **error**: better scope errors ([#138](https://github.com/PlaceOS/models/pull/138))

## v6.1.0 (2022-02-04)

### Feat

- **user**: add department and preferred_language ([#140](https://github.com/PlaceOS/models/pull/140))

## v6.0.1 (2022-02-01)

### Fix

- **settings**: return previous order of settings ([#139](https://github.com/PlaceOS/models/pull/139))

## v6.0.0 (2022-01-25)

### Fix

- **settings**: merge down encryption levels ([#137](https://github.com/PlaceOS/models/pull/137))

## v5.15.3 (2022-01-11)

### Feat

- **user model**: expose the deleted flag ([#135](https://github.com/PlaceOS/models/pull/135))

## v5.15.2 (2021-12-14)

### Feat

- **repository**: add release flag for loader ([#134](https://github.com/PlaceOS/models/pull/134))

## v5.15.1 (2021-12-03)

### Feat

- add models required for asset manager ([#130](https://github.com/PlaceOS/models/pull/130))

### Fix

- **asset_instance**: add missing name attribute ([#133](https://github.com/PlaceOS/models/pull/133))

## v5.14.2 (2021-11-25)

### Feat

- **base jwt**: allow optional validation ([#131](https://github.com/PlaceOS/models/pull/131))

## v5.14.1 (2021-11-11)

### Fix

- **user**: annotation on email attribute

## v5.14.0 (2021-11-03)

### Fix

- more detailed log about which secret is unset

### Refactor

- **encryption**: expose the secret in the arguments ([#128](https://github.com/PlaceOS/models/pull/128))

## v5.13.0 (2021-10-25)

### Feat

- implement `ApiKey.saas_api_key` ([#126](https://github.com/PlaceOS/models/pull/126))

## v5.12.3 (2021-10-22)

### Feat

- **user**: extend look up methods ([#127](https://github.com/PlaceOS/models/pull/127))

### Fix

- **generator:metadata**: typo ([#125](https://github.com/PlaceOS/models/pull/125))

## v5.12.1 (2021-10-11)

### Fix

- **module**: don't fail to merge all settings ([#124](https://github.com/PlaceOS/models/pull/124))

## v5.12.0 (2021-10-07)

### Feat

- **settings_helper**: add `#settings_hierarchy`

### Fix

- **settings**: improve YAML validation ([#121](https://github.com/PlaceOS/models/pull/121))
- **settings**: improve YAML validation
- **api_key**: set es_types for complex types

### Refactor

- **user**: add Email struct ([#123](https://github.com/PlaceOS/models/pull/123))
- **repository**: remove `key`

### Perf

- **settings**: improve parent look up

## v5.9.1 (2021-08-16)

### Feat

- **user**: perform a case insensitive email lookup

### Fix

- **user_jwt**: rename undefined constant

## v5.8.1 (2021-08-16)

### Feat

- add scope struct to jwt ([#111](https://github.com/PlaceOS/models/pull/111))

## v5.8.0 (2021-07-23)

### Feat

- add helpers for rendering
- add API key model

### Fix

- ensure ID is returned in the JSON response
- edge decrypt method
- don't double up on authority_id
- specs and use SHA512 as bcrypt is too slow

## v5.7.5 (2021-07-20)

### Fix

- **repository**: check presence before encrypting

## v5.7.4 (2021-07-15)

### Fix

- set es-type for schema fields

## v5.7.2 (2021-07-13)

### Feat

- **user**: `to_groups_json`
- **doorkeeper**: ensure uniqueness of name + URL

### Fix

- `name` es_type

### Refactor

- use `define_to_json`


- `name` es_type"

## v5.5.2 (2021-06-28)

### Fix

- ensure unique zone names

## v5.5.1 (2021-06-22)

### Feat

- add UserJWT as type to decrypt for

### Fix

- remove focus true

## v5.5.0 (2021-06-09)

### Fix

- **repository**: encryption for `password`, `token`
- **models**: correct es types


- "chore: remove docs key from .gitignore"

## v5.4.0 (2021-06-07)

### Feat

- **version**: add platform_version

### Fix

- move default args to last
- **ci/publish**: `crystal tool docs` -> `crystal docs`
- **version**: use string for date field

## v5.3.0 (2021-06-04)

### Feat

- add a `Version` struct for use across all services

## v5.2.0 (2021-06-04)

### Feat

- move to using a JSON schema table
- add support for storing JSON schema

### Fix

- add the schema generator
- use an object instead of parsing the default
- move json schema to metadata
- supply default
- supply default

## v5.1.1 (2021-06-02)

### Feat

- **trigger conditions**: add support for timezones in CRON
- **user**: ensure an admin user remains present

### Refactor

- **trigger/conditions/comparison**: use record for StatusVariable
- **trigger/conditions/comparison**: use enum for operator validation

## v4.18.2 (2021-04-30)

### Fix

- **authority**: allow raw domains to be set

## v4.18.1 (2021-04-28)

### Fix

- **generator**: correct arguments for JWT mock

## v4.18.0 (2021-04-27)

### Feat

- **zone**: add `.with_tag` query

### Fix

- **edge**: ensure seperator not present in secret or id

## v4.17.0 (2021-04-24)

### Feat

- **control_system**: log on module removal
- **error**: add cause

### Fix

- **user_auth_lookup**: set new_flag in generate_id callback
- **edge**: remove `_` from secret to prevent splits on the char
- **settings**: validate `settings_string`

### Refactor

- **trigger:actions**: cleanup
- **trigger:conditions**: cleanup
- **user_jwt**: cleanup duplicate attributes
- **zone**: touch up accessors
- **control_system**: tidy up accessors
- **settings_spec**: remove redundant rescues
- **settings**: reorder file

## v4.15.5 (2021-04-14)

### Fix

- **module**: force no tls only when udp ([#79](https://github.com/PlaceOS/models/pull/79))
- **repository**: correctly serialise to_reql
- **base/model**: submodels were not correctly serialising to reql

## v4.15.3 (2021-03-29)

### Fix

- **driver:role**: define to_json on enum
- **driver**: value converter for driver role

## v4.15.1 (2021-03-25)

### Fix

- fully qualify converters
- **workflows crystal.yml**: ignore crystal version

### Refactor

- **user_jwt**: slight clean up

## v4.14.1 (2021-03-23)

### Feat

- **metadata**: add schema field
- **driver**: add field for compilation output

### Refactor

- **validation**: add a helper for URI validation

## v4.12.1 (2021-02-10)

### Feat

- **control_system**: add images[] to hold references to image URLs

### Fix

- **edge**: catch errors from invalid base64
- **interface**: explicitly set a pull commit

## v4.10.2 (2021-02-02)

### Fix

- **module**: minor style change

## v4.10.1 (2021-01-28)

### Feat

- **user**: add a bulk user by email query
- **user**: selective update for admin managed fields

### Fix

- **control_system**: conform to new delete interface
- **user**: prevent mass assignment of privilege

### Refactor

- **edge**: deprecate `validate_token` in favour of `validate_token?`
- **user**: publically expose user's groups
- **user**: clean up and organisation of methods
- use has_control? getter that checks presence of association

## v4.8.3 (2020-12-15)

### Refactor

- **model:module**: change type hint on ip

## v4.8.2 (2020-12-09)

### Fix

- **edge**: base64 token

## v4.8.1 (2020-12-04)

### Feat

- **edge**: add token validation
- **edge**: add token generation method

### Fix

- **edge**: prevent mass assignment of edge secret

## v4.7.1 (2020-12-03)

### Fix

- incorrect elasticsearch type hint

## v4.7.0 (2020-11-27)

### Feat

- **edge**: encryption methods on field basis, add check?
- **encryption**: add `check?` to compare a plaintext value against ciphertext
- **edge**: secret validation

## v4.6.1 (2020-11-24)

## v4.6.0 (2020-11-18)

### Feat

- **module**: fetch modules by edge_id

### Fix

- **module**: ensure only logic modules have parent systems
- **repository**: validate no spaces in `folder_name`

## v4.5.3 (2020-10-28)

### Feat

- **metadata**: add editors to record interface
- **metadata**: add editors field

## v4.5.2 (2020-10-27)

### Fix

- **module**: edge import

## v4.5.1 (2020-10-21)

### Feat

- **module**: add edge hint to module
- **edge**: add edge model that represents an edge node
- **metadata**: add support for user level metadata

### Fix

- **user**: rename clashing field to `misc`
- **user**: has_many metadatas to not clash with local metadata

### Refactor

- **encryption**: move encryption visibility logic to `Level` enum
- **settings**: use `Encryption.decrypt_for` helper

## v4.4.1 (2020-09-22)

### Feat

- **module**: #logic_for query by parent control_system

### Fix

- typos
- **jwt**: default to PUBLIC_KEY in decode and PRIVATE_KEY in encode

## v4.2.4 (2020-08-31)

### Feat

- **user-jwt**: add scope field

### Fix

- **user-jwt**: initialize scope

## v4.2.3 (2020-08-12)

### Fix

- **user**: staff_id and login_name don't enforce uniquness

## v4.2.2 (2020-08-11)

### Feat

- **user_jwt**: jwt includes user roles

## v4.2.1 (2020-08-11)

### Feat

- **control-system**: add timezone field

### Fix

- **module**: #resolved_name should not be nillable
- set subfield keyword for name attributes
- **user**: protect some attributes related to user roles

### Refactor

- **metadata**: serialize `Metadata#details` to String
- use updated rethink-orm

## v3.3.0 (2020-07-29)

### Feat

- add access token fields and expose additional fields

## v3.2.0 (2020-07-24)

### Feat

- **oauth authentication**: additional fields to support google

### Fix

- **control_system**: remove module from features in `remove_module`
- **module**: role case statement

## v3.1.0 (2020-07-07)

### Feat

- **repository**: add `branch` field

### Fix

- **settings**: raise Model::Error on failed parse

### Refactor

- use `case...in` over `case...when` where possible

## v3.0.5 (2020-07-03)

### Feat

- **metadata**: make parent_id optional on interface

## v3.0.4 (2020-07-03)

### Fix

- **metadata**: scope query under correct table; add specs

## v3.0.3 (2020-07-03)

## v3.0.2 (2020-07-03)

### Feat

- **metadata**: generic metadata model

### Fix

- **metadata**: include JSON::Serializable in interface record
- **metadata**: rename `Response` to `Interface`; set non-nillable fields
- **user jwt**: admin should be considered support

## v2.1.4 (2020-07-01)

### Fix

- **user**: password saving on JSON parse ([#33](https://github.com/PlaceOS/models/pull/33))
- **doorkeeper-app**: use UID as id, if id not generated

## v2.1.3 (2020-06-30)

### Feat

- **user**: add groups attribute

## v2.1.2 (2020-06-26)

### Fix

- **authority**: destroy dependent users, oauth strats, ldap strats, and saml strats

## v2.1.0 (2020-06-18)

### Fix

- **control-system**: generate resolved module names ([#29](https://github.com/PlaceOS/models/pull/29))

## v2.0.3 (2020-06-15)

### Fix

- **encryption**: use `Digest#final`

## v2.0.2 (2020-06-03)

### Fix

- **repository**: destroy dependent drivers on destroy

## v2.0.0 (2020-05-29)

### Fix

- **shard.yml**: duplicate version field
- **broker**: correct default port for non-tls connections

### Refactor

- rename top-level import `placeos-models` ([#23](https://github.com/PlaceOS/models/pull/23))
- **broker**: `ip` -> `host`, validate presence of conneciton information

## v1.2.0 (2020-05-21)

### Feat

- **broker**: sanitize a string dependent on Broker's filters
- **broker**: validate filters
- **broker**: model::Broker base implementation

### Refactor

- **broker**: use secret rather than a public scope as key for HMAC
- **broker**: drop lazy enum proc, drop intermediate hash when rendering filter errors

## v1.0.10 (2020-05-18)

### Feat

- improve doorkeeper app UID generation
- **utilities:encryption**: use `PLACE_SERVER_SECRET` env var

### Fix

- **doorkeeper_app**: only set uid if empty

## v1.0.9 (2020-05-14)

### Fix

- **doorkeeper application**: UID is an MD5 of the redirect

## v1.0.8 (2020-05-13)

## v1.0.7 (2020-05-13)

### Fix

- **authority**: default to argument if URI fails to parse host in `find_by_domain`

## v1.0.6 (2020-05-12)

### Fix

- **authority**: remove prefix of `login_url`

## v1.0.5 (2020-05-12)

### Fix

- **authority**: only save host of domain

### Perf

- **user**: add missing indices

## v1.0.4 (2020-04-27)

### Feat

- **statistics**: add stats model

### Fix

- **user**: catch auth cleanup failures
- **statistics spec**: ensure ttl isn't nil

## v1.0.3 (2020-04-22)

### Feat

- add some common metadata
- **user**: add auth token cleanup
- **user_auth_lookup**: clean up on user destroy

### Fix

- **repository**: reql serialisation for `ensure_unique`
- **user_spec**: remove destroy spec
- **repository**: add note about scoping unique check
- **repository**: folder name uniquness
- **repository**: folder name uniqueness scoping
- **settings**: enum_attribute ParentType and rearrange to allow symbol resolution

## v1.0.0 (2020-04-10)

### Fix

- rest-api dependencies
- dependencies

## v0.8.1 (2020-04-08)

### Feat

- **driver**: recompilation helpers

## v0.7.4 (2020-04-06)

### Fix

- **repository**: use 'HEAD' over 'head'

## v0.7.2 (2020-04-01)

## v0.7.1 (2020-03-31)

## v0.7.0 (2020-03-30)

### Feat

- **control_system**: methods for adding/removing a module
- **zone-metadata**: add support zone metadata
- **settings**: `Settings#dependent_modules`
- **module**: `Module.in_zone` and `Module.in_control_system`
- **zone**: add support for hierarchies
- **control_system**: add `Model::ControlSystem#settings_hierarchy`

### Fix

- **module**: add module to ControlSystem if control_system_id is set
- uniqueness checks should be scoped appropriately
- **zone spec**: children iterator
- **control_system**: don't raise on missing zone in `ControlSystem#settings_hierarchy`
- **settings#history**: return versions in descending creation time, create version after save
- **module**: driver could be nil
- **module**: ensure name and role are configured correctly
- **user**: don't allow mass assignment of digests

### Refactor

- **module**: extract hierarchy from generation of merged_settings
- add explicit imports to improve single model imports
- **settings_helper**: remove macro hack

### Perf

- use `reverse!` where appropriate
- **settings**: optimise `Settings.master_settings_query`

## v0.5.2 (2020-03-17)

### Fix

- **control_system**: ensure_unique destructively transforms

## v0.5.1 (2020-03-13)

### Refactor

- `ACAEngine` -> `PlaceOS`, `engine-models` -> `models`

## v0.4.1 (2020-03-02)

### Feat

- **authentication**: add models used for specifying auth sources

### Fix

- **user_spec**: apply `JSON.parse` to json string rather than NamedTuple
- **subset_json**: remove call to `to_json`

### Refactor

- **driver**: remove `version` field in favour of commit hash

## v0.3.0 (2020-01-21)

### Feat

- **doorkeeper**: add doorkeeper application model to crystal
- **user**: add bcrypt password support
- update driver roles to include websocket
- add exec_enabled attribute
- **settings**: `is_encrypted?` helper
- **settings**: `get_setting_for?`
- **settings**: implement various queries
- **module**: updated `merge_settings`
- **settings**: settings helpers
- **settings**: implement base of Settings model
- **module**: driver's `module_name` in Module as `name`
- **driver**: repository required on driver
- seperate models from api

### Fix

- **doorkeeper app**: use UInt64 to represent revoked time
- **doorkeeper app**: Bool not Boolean
- **authority**: add timestamps and use `JSON::Any`
- **repository**: fix conflict between `type` fields in elastic search by renameing to `repo_type`
- **trigger**: add additional supported webhook methods
- **settings**: nillable hash conversion for empty 'settings_string'
- **repository|driver**: correct foreign key for Repository + Driver AssociationCollection
- **trigger**: constant should be 64bits to match JSON
- **settings**: identity block
- **settins**: macro workaround due to generic module compiler bug
- **spec:generator**: exhaustive case is not a thing yet
- **module**: boolean defaults for udp and tls
- correct imports
- fix imports, move encryption

### Refactor

- explicitly state foreign key of associations
- **trigger webhook**: merge webhook fields into root of trigger
- **trigger**: simplify webhook submodel
- **settings**: redundant over-ride of association setters
