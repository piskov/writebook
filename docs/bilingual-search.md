# English and Russian search

Search automatically applies SQLite's existing Porter stemmer to English words
and Snowball's Russian stemmer to words made entirely of Russian letters. Both
languages work in the same book, page, query, and quoted phrase. Other tokens
retain Unicode matching. This is alphabet-based routing, not language detection:
other languages sharing the same letters are not guaranteed correct stemming.
Mixed alphanumeric or mixed-script tokens are not stemmed. Existing Unicode
token boundaries and Latin accent folding remain in effect.

Original text is stored unchanged in the FTS table. The tokenizer returns stems
with the original byte offsets so SQLite snippets and highlighting still show
the author's words. There is no separate search server or dictionary download.

## Production upgrade

1. Stop the old container and back up its complete persistent storage.
2. Start the new image with the same `/rails/storage` volume or bind mount and
   the same environment settings, including any configured secret key.
3. Startup already runs `bin/rails db:prepare`. Migration `20260921090000` builds
   the new index from the original text in the existing FTS table, inside one
   transaction. It leaves books, accounts, pages, and uploaded files untouched.
4. Wait for the app to become ready. A large index can extend first startup and
   temporarily needs disk space for both indexes and SQLite transaction files.
   Subsequent starts do not repeat the migration.

The image compiles and includes the tokenizer and its Snowball runtime library;
no host installation or manual reindex command is needed. Do not run the old and
new app simultaneously against the same SQLite storage during the upgrade.
If migration fails, the transaction restores the original index; diagnose the
startup error and retry. The migration copies existing index rows, so it does
not repair content that was already missing from the old index.

## Rollback

The old image cannot use the new tokenizer. Stop the new application, then use
the **new image** with the same storage and environment to run:

```sh
bin/rails db:migrate:down VERSION=20260921090000
```

This rebuilds the Porter index from the current original indexed text, retaining
content changes made after upgrading. Then start the old image. Alternatively,
restore the complete pre-upgrade storage backup with the app stopped (which
also discards changes made after that backup). Starting the new image again
after rollback automatically reapplies the migration.

## Local development

Docker handles compilation automatically. For a Linux development environment,
install a C compiler, SQLite headers, and Snowball headers/library (Debian:
`build-essential libsqlite3-dev libstemmer-dev`), then run:

```sh
sh bin/build-search-extension
bin/rails db:prepare
```

`bin/setup` also builds the extension before preparing the database. The compiled
`.so` is ignored by Git and Docker's build context; every Docker build compiles
for its own target architecture. Database connections load the extension through
Rails' SQLite `extensions` configuration, including migration and test connections.

Changing tokenizer rules requires a new tokenizer version and index migration;
do not silently change the meaning of `writebook_en_ru_v1` in a future release.
