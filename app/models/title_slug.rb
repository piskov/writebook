module TitleSlug
  def self.generate(title)
    title.to_s.unicode_normalize(:nfc).downcase
      .gsub(/[^\p{L}\p{M}\p{N}-]+/, "-")
      .gsub(/-+/, "-").delete_prefix("-").delete_suffix("-").presence || "-"
  end
end
