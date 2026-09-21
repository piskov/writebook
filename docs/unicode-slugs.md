# Unicode book and page URLs

Generated slugs preserve Unicode letters, combining marks, and numbers. Titles
are normalized to NFC, lowercased, and separated with hyphens. Empty titles or
titles containing only punctuation or emoji use `-` so URLs remain routable.
Browsers may display Cyrillic characters directly or as percent-encoded bytes;
both representations identify the same URL.

Books keep their existing nonempty slugs when renamed. Publication slugs can be
edited using letters from any language, numbers, and hyphens. Existing slugs
are not revalidated unless changed. Page slugs are derived from their titles.

Migration `20260921120000` fills only blank book slugs, without changing titles,
permissions, content, or nonempty custom slugs. It is safe to rerun and keeps
repaired values on rollback. No search reindex is needed. Deploy the image with
the existing storage and environment; the normal database preparation on
startup applies the migration.

Routing continues to identify records by numeric IDs. Older nonempty slugs,
book links without a slug, and page links with an empty book-slug segment remain
usable. The existing login and book-access checks apply to these links too.
