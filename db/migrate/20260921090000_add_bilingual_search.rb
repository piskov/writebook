class AddBilingualSearch < ActiveRecord::Migration[8.0]
  def up
    replace_index("writebook_en_ru_v1")
  end

  def down
    replace_index("porter")
  end

  private
    def replace_index(tokenizer)
      # Rails wraps this migration in a transaction. Keep the original index
      # until the new one is fully populated; any failure restores the old one.
      # Copy original, unstemmed text from FTS storage, without model callbacks
      # or loading all books into memory. Source records/uploads are untouched.
      create_virtual_table "leaf_search_index_next", "fts5",
        [ "title", "content", "tokenize='#{tokenizer}'" ]
      execute <<~SQL
        INSERT INTO leaf_search_index_next(rowid, title, content)
        SELECT rowid, title, content FROM leaf_search_index
      SQL
      drop_table "leaf_search_index"
      execute "ALTER TABLE leaf_search_index_next RENAME TO leaf_search_index"
    end
end
