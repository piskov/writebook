require "test_helper"
require Rails.root.join("db/migrate/20260921090000_add_bilingual_search")

class BilingualSearchMigrationTest < ActiveSupport::TestCase
  setup do
    pages(:welcome).update! body: "running лошади"
    Leaf.reindex_all
    AddBilingualSearch.new.migrate(:down)
  end

  test "upgrade and rollback preserve indexed text and source records" do
    connection = ActiveRecord::Base.connection
    indexed = connection.select_rows("SELECT rowid, title, content FROM leaf_search_index ORDER BY rowid")
    originals = source_rows
    assert_empty Leaf.search("лошадь")

    AddBilingualSearch.new.migrate(:up)

    assert_includes Leaf.search("runs лошадь"), leaves(:welcome_page)
    assert_equal indexed, connection.select_rows("SELECT rowid, title, content FROM leaf_search_index ORDER BY rowid")
    assert_equal originals, source_rows

    # Rollback retains edits made after upgrading, rather than an old snapshot.
    pages(:welcome).update! body: "correcting книги"
    AddBilingualSearch.new.migrate(:down)
    assert_includes Leaf.search("corrected книги"), leaves(:welcome_page)
    assert_empty Leaf.search("книга")

    AddBilingualSearch.new.migrate(:up)
    assert_includes Leaf.search("corrected книга"), leaves(:welcome_page)
  end

  test "failed upgrade leaves the original index usable" do
    failing_migration = Class.new(AddBilingualSearch) do
      def drop_table(*)
        raise "Simulated failure after populating replacement index"
      end
    end

    assert_raises(RuntimeError) do
      ActiveRecord::Base.transaction(requires_new: true) do
        failing_migration.new.up
      end
    end

    assert_includes Leaf.search("runs лошади"), leaves(:welcome_page)
    assert_empty Leaf.search("лошадь")
    assert_not ActiveRecord::Base.connection.table_exists?("leaf_search_index_next")
  end

  private
    def source_rows
      %w[accounts books leaves pages sections users active_storage_blobs active_storage_attachments action_text_markdowns].to_h do |table|
        [ table, ActiveRecord::Base.connection.select_rows("SELECT * FROM #{table} ORDER BY id") ]
      end
    end
end
