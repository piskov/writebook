require "test_helper"

class SearchTokenizerTest < ActiveSupport::TestCase
  test "each new SQLite connection loads the tokenizer and preserves byte offsets" do
    2.times do
      SQLite3::Database.new(":memory:", extensions: [ Rails.root.join("lib/sqlite/writebook_search.so").to_s ]) do |db|
        db.execute("CREATE VIRTUAL TABLE words USING fts5(body, tokenize='writebook_en_ru_v1')")
        db.execute("INSERT INTO words VALUES (?)", [ "🙂 Café running ЛОШАДЬ лошади лошадью" ])
        result = db.get_first_value("SELECT highlight(words, 0, '<mark>', '</mark>') FROM words WHERE words MATCH ?",
          [ '"runs" "лошадь"' ])
        assert_equal "🙂 Café <mark>running</mark> <mark>ЛОШАДЬ</mark> <mark>лошади</mark> <mark>лошадью</mark>", result
      end
    end
  end

  test "English stems are identical to SQLite Porter" do
    SQLite3::Database.new(":memory:", extensions: [ Rails.root.join("lib/sqlite/writebook_search.so").to_s ]) do |db|
      db.execute("CREATE VIRTUAL TABLE old_words USING fts5(body, tokenize='porter')")
      db.execute("CREATE VIRTUAL TABLE new_words USING fts5(body, tokenize='writebook_en_ru_v1')")
      db.execute("CREATE VIRTUAL TABLE old_vocab USING fts5vocab(old_words, 'row')")
      db.execute("CREATE VIRTUAL TABLE new_vocab USING fts5vocab(new_words, 'row')")
      text = "running runs correcting corrected studies studying horses relational generously #{'a' * 80}"
      db.execute("INSERT INTO old_words VALUES (?)", [ text ])
      db.execute("INSERT INTO new_words VALUES (?)", [ text ])
      assert_equal db.execute("SELECT term FROM old_vocab ORDER BY term"), db.execute("SELECT term FROM new_vocab ORDER BY term")
    end
  end
end
