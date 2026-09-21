class RepairEmptyBookSlugs < ActiveRecord::Migration[8.0]
  class Book < ActiveRecord::Base
    self.table_name = "books"
  end

  def up
    Book.select(:id, :title, :slug).find_each do |book|
      next unless book.slug.blank?

      # Keep this data migration independent of future application slug rules.
      slug = book.title.to_s.unicode_normalize(:nfc).downcase
        .gsub(/[^\p{L}\p{M}\p{N}-]+/, "-")
        .gsub(/-+/, "-").delete_prefix("-").delete_suffix("-").presence || "-"
      book.update_columns(slug: slug)
    end
  end

  def down
    # Repaired slugs also work with the previous app; do not recreate broken links.
  end
end
