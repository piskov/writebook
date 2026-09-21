/* FTS5 tokenizer: Unicode word boundaries, SQLite Porter for English, and
 * Snowball for Russian. Original byte offsets keep snippets/highlights intact.
 * Change the tokenizer name and migrate the index when token rules change. */
#include <sqlite3ext.h>
SQLITE_EXTENSION_INIT1
#include <libstemmer.h>
#include <string.h>

typedef int (*TokenCallback)(void *, int, const char *, int, int, int);

typedef struct {
  fts5_tokenizer unicode_api;
  fts5_tokenizer porter_api;
  Fts5Tokenizer *unicode;
  Fts5Tokenizer *porter;
  struct sb_stemmer *russian;
} SearchTokenizer;

typedef struct {
  SearchTokenizer *tokenizer;
  void *context;
  TokenCallback emit;
  int flags;
  int token_flags;
  int start;
  int end;
} TokenContext;

static void search_delete(Fts5Tokenizer *instance) {
  SearchTokenizer *t = (SearchTokenizer *)instance;
  if (t->unicode) t->unicode_api.xDelete(t->unicode);
  if (t->porter) t->porter_api.xDelete(t->porter);
  if (t->russian) sb_stemmer_delete(t->russian);
  sqlite3_free(t);
}

static int search_create(void *context, const char **args, int count,
                         Fts5Tokenizer **result) {
  fts5_api *api = (fts5_api *)context;
  SearchTokenizer *t;
  void *unicode_context = 0, *porter_context = 0;
  int rc;
  (void)args;
  *result = 0;
  if (count != 0) return SQLITE_ERROR;
  t = sqlite3_malloc(sizeof(*t));
  if (!t) return SQLITE_NOMEM;
  memset(t, 0, sizeof(*t));
  rc = api->xFindTokenizer(api, "unicode61", &unicode_context, &t->unicode_api);
  if (rc == SQLITE_OK)
    rc = api->xFindTokenizer(api, "porter", &porter_context, &t->porter_api);
  if (rc == SQLITE_OK)
    rc = t->unicode_api.xCreate(unicode_context, 0, 0, &t->unicode);
  if (rc == SQLITE_OK)
    rc = t->porter_api.xCreate(porter_context, 0, 0, &t->porter);
  if (rc == SQLITE_OK) {
    t->russian = sb_stemmer_new("russian", "UTF_8");
    if (!t->russian) rc = SQLITE_NOMEM;
  }
  if (rc != SQLITE_OK) {
    search_delete((Fts5Tokenizer *)t);
    return rc;
  }
  *result = (Fts5Tokenizer *)t;
  return SQLITE_OK;
}

/* unicode61 has already case-folded the token. Only accept Russian а-я/ё,
 * not all Cyrillic: Ukrainian-specific letters and mixed identifiers pass on. */
static int is_russian(const unsigned char *word, int length) {
  int i;
  if (length == 0 || length % 2 != 0) return 0;
  for (i = 0; i < length; i += 2) {
    if (!((word[i] == 0xd0 && word[i + 1] >= 0xb0 && word[i + 1] <= 0xbf) ||
          (word[i] == 0xd1 && word[i + 1] >= 0x80 && word[i + 1] <= 0x8f) ||
          (word[i] == 0xd1 && word[i + 1] == 0x91))) return 0;
  }
  return 1;
}

static int is_english(const unsigned char *word, int length) {
  int i;
  if (length == 0) return 0;
  for (i = 0; i < length; i++) {
    if (word[i] < 'a' || word[i] > 'z') return 0;
  }
  return 1;
}

static int emit_english(void *context, int flags, const char *word, int length,
                        int start, int end) {
  TokenContext *c = (TokenContext *)context;
  (void)flags;
  (void)start;
  (void)end;
  return c->emit(c->context, c->token_flags, word, length, c->start, c->end);
}

static int stem_token(void *context, int flags, const char *word, int length,
                      int start, int end) {
  TokenContext *c = (TokenContext *)context;
  if (is_russian((const unsigned char *)word, length)) {
    const sb_symbol *stem = sb_stemmer_stem(c->tokenizer->russian,
                                           (const sb_symbol *)word, length);
    if (!stem) return SQLITE_NOMEM;
    return c->emit(c->context, flags, (const char *)stem,
                   sb_stemmer_length(c->tokenizer->russian), start, end);
  }
  if (is_english((const unsigned char *)word, length)) {
    c->token_flags = flags;
    c->start = start;
    c->end = end;
    return c->tokenizer->porter_api.xTokenize(c->tokenizer->porter, c, c->flags,
                                             word, length, emit_english);
  }
  return c->emit(c->context, flags, word, length, start, end);
}

static int search_tokenize(Fts5Tokenizer *instance, void *context, int flags,
                           const char *text, int length, TokenCallback emit) {
  SearchTokenizer *t = (SearchTokenizer *)instance;
  TokenContext c = { t, context, emit, flags, 0, 0, 0 };
  return t->unicode_api.xTokenize(t->unicode, &c, flags, text, length, stem_token);
}

#ifdef _WIN32
__declspec(dllexport)
#endif
int sqlite3_writebooksearch_init(sqlite3 *db, char **error,
                               const sqlite3_api_routines *routines) {
  fts5_api *api = 0;
  sqlite3_stmt *statement = 0;
  fts5_tokenizer tokenizer = { search_create, search_delete, search_tokenize };
  int rc;
  SQLITE_EXTENSION_INIT2(routines);
  rc = sqlite3_prepare_v2(db, "SELECT fts5(?1)", -1, &statement, 0);
  if (rc == SQLITE_OK) {
    rc = sqlite3_bind_pointer(statement, 1, &api, "fts5_api_ptr", 0);
    if (rc == SQLITE_OK) {
      int step = sqlite3_step(statement);
      rc = step == SQLITE_ROW ? SQLITE_OK : step;
    }
  }
  sqlite3_finalize(statement);
  if (rc != SQLITE_OK) return rc;
  if (!api) {
    *error = sqlite3_mprintf("Writebook search requires SQLite FTS5");
    return SQLITE_ERROR;
  }
  return api->xCreateTokenizer(api, "writebook_en_ru_v1", api, &tokenizer, 0);
}
