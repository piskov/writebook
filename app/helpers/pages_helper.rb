module PagesHelper
  def word_count(content)
    return if content.blank?
    count = content.split.size
    t("word_count", count: count, formatted_count: number_with_delimiter(count))
  end

  def page_title(leaf, book)
    [ leaf.title, book.title, book.author ].reject(&:blank?).to_sentence(two_words_connector: " · ", words_connector: " · ", last_word_connector: " · ")
  end

  def sanitize_content(content)
    sanitize content, scrubber: HtmlScrubber.new
  end
end
