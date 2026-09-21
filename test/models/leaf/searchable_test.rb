require "test_helper"

class Leaf::SearchableTest < ActiveSupport::TestCase
  setup do
    Leaf.reindex_all
  end

  test "leaf body is indexed and searchable" do
    leaves = Leaf.search("great handbook")
    assert_includes leaves, leaves(:welcome_page)
  end

  test "query preparation preserves Unicode words and phrases" do
    {
      "привет" => '"привет"',
      "ПРИВЕТ" => '"ПРИВЕТ"',
      "hello, мир!" => '"hello" "мир"',
      '"привет мир"' => '"привет мир"',
      "Ελληνικά café 中文测试" => '"Ελληνικά" "café" "中文测试"',
      "cafe\u0301" => "\"cafe\u0301\""
    }.each do |query, expected|
      assert_equal expected, Leaf.sanitize_query_syntax(query), query
    end
  end

  test "Cyrillic titles and bodies are searchable with Unicode case folding" do
    leaf = leaves(:welcome_page)
    leaf.update! title: "Руководство"
    pages(:welcome).update! body: "Привет мир"
    leaf.reload.reindex

    assert_includes Leaf.search("РУКОВОДСТВО"), leaf
    assert_includes Leaf.search("ПРИВЕТ"), leaf
    result = Leaf.search("руководство привет").find(leaf.id)
    assert_equal "<mark>Руководство</mark>", result.title_match
    assert_includes result.content_match, "<mark>Привет</mark>"
    assert_equal [ "Привет" ], leaf.matches_for_highlight("ПРИВЕТ")
  end

  test "mixed language queries require all terms" do
    pages(:welcome).update! body: "hello мир"
    sections(:welcome).update! body: "hello world"
    leaves(:welcome_section).reindex

    results = Leaf.search("hello мир")
    assert_includes results, leaves(:welcome_page)
    assert_not_includes results, leaves(:welcome_section)
    assert_empty Leaf.search("hello отсутствует")
  end

  test "search accepts words from multiple scripts" do
    pages(:welcome).update! body: "Ελληνικά café 中文测试"

    %w[Ελληνικά café 中文测试].each do |query|
      assert_includes Leaf.search(query), leaves(:welcome_page), query
    end
  end

  test "Cyrillic quoted phrases require adjacent words even after empty quotes" do
    pages(:welcome).update! body: "привет мир"
    sections(:welcome).update! body: "привет прекрасный мир"
    leaves(:welcome_section).reindex

    [ '"привет мир"', '"" "привет мир"' ].each do |query|
      results = Leaf.search(query)
      assert_includes results, leaves(:welcome_page)
      assert_not_includes results, leaves(:welcome_section)
    end
  end

  test "search retains English stemming" do
    pages(:welcome).update! body: "correcting"

    assert_includes Leaf.search("corrected"), leaves(:welcome_page)
  end

  test "Russian noun forms match in both directions and highlight original text" do
    leaf = leaves(:welcome_page)
    %w[лошадь лошади лошадью].each do |word|
      leaf.update! title: word
      pages(:welcome).update! body: "Здесь #{word}."
      leaf.reload.reindex

      %w[лошадь ЛОШАДИ лошадью].each do |query|
        result = Leaf.search(query).find(leaf.id)
        assert_equal "<mark>#{word}</mark>", result.title_match
        assert_includes result.content_match, "<mark>#{word}</mark>"
        assert_equal [ word ], leaf.matches_for_highlight(query)
      end
    end
  end

  test "English and Russian stems work together in queries and phrases" do
    pages(:welcome).update! body: "running лошади"
    sections(:welcome).update! body: "running красивые лошади"
    leaves(:welcome_section).reindex

    assert_includes Leaf.search("runs лошадь"), leaves(:welcome_page)
    assert_includes Leaf.search("runs лошадь"), leaves(:welcome_section)
    assert_includes Leaf.search('"runs лошадь"'), leaves(:welcome_page)
    assert_not_includes Leaf.search('"runs лошадь"'), leaves(:welcome_section)
    assert_empty Leaf.search("swimming лошадь")
  end

  test "bilingual index follows edits and deletes" do
    leaf = leaves(:welcome_page)
    pages(:welcome).update! body: "лошади"
    assert_includes Leaf.search("лошадь"), leaf

    pages(:welcome).update! body: "книги"
    assert_not_includes Leaf.search("лошадь"), leaf
    assert_includes Leaf.search("книга"), leaf

    leaf.destroy!
    assert_empty Leaf.search("книга")
  end

  test "other scripts and mixed identifiers are not Russian or English stemmed" do
    pages(:welcome).update! body: "running123 лошади42 testлошади Ελληνικά 中文测试"

    %w[running123 лошади42 testлошади Ελληνικά 中文测试].each do |query|
      assert_includes Leaf.search(query), leaves(:welcome_page)
    end
    assert_empty Leaf.search("run123")
    assert_empty Leaf.search("лошадь42")
    assert_empty Leaf.search("testлошадь")
  end

  test "updating a leaf updates the search index" do
    pages(:welcome).update! body: "sausages"

    leaves = Leaf.search("sausages")
    assert_includes leaves, leaves(:welcome_page)
  end

  test "search includes highlighted matches" do
    leaves = Leaf.search("great handbook")
    assert_includes leaves.first.title_match, "The <mark>Handbook</mark>"
    assert_includes leaves.first.content_match, "<mark>great</mark> <mark>handbook</mark>"
  end

  test "leaves with no searchable content are not indexed" do
    leaves = Leaf.search("welcome")
    assert_not_includes leaves, leaves(:welcome_section)
  end

  test "matches_for_highlight returns the matching terms, longest first" do
    matches = leaves(:welcome_page).matches_for_highlight("great handbook")
    assert_equal [ "handbook", "great" ], matches
  end

  test "matches_for_highlight is empty when there is no match" do
    markup = leaves(:welcome_page).matches_for_highlight("haggis")
    assert_empty markup
  end

  test "matches_for_highlight is empty when the query sanitizes to nothing" do
    assert_empty leaves(:welcome_page).matches_for_highlight("^$")
    assert_empty leaves(:welcome_page).matches_for_highlight("🙂")
    assert_empty leaves(:welcome_page).matches_for_highlight("\"")
  end

  test "search treats FTS5 operators as literal terms rather than syntax" do
    assert_empty Leaf.search("OR")
    assert_empty Leaf.search("great AND NOT")
    assert_empty Leaf.search("great OR handbook")

    assert_includes Leaf.search("great handbook"), leaves(:welcome_page)
    assert_includes Leaf.search("\"great handbook\""), leaves(:welcome_page)
  end

  test "a stray empty quote pair does not split a following phrase" do
    sections(:welcome).update!(body: "great old handbook")
    leaves(:welcome_section).reindex

    results = Leaf.search("\"\" \"great handbook\"")

    assert_includes results, leaves(:welcome_page)
    assert_not_includes results, leaves(:welcome_section)
  end

  test "search does not raise on invalid UTF-8 byte sequences" do
    malformed = "caf\xFF".dup.force_encoding("UTF-8")
    assert_not malformed.valid_encoding?

    assert_nothing_raised do
      assert_empty Leaf.search(malformed)
      assert_empty leaves(:welcome_page).matches_for_highlight(malformed)
    end
  end

  test "indexing sanitizes section body" do
    section = Section.new(body: 'findme Tom & Jerry <img src=x onerror="alert(1)">')
    books(:handbook).press(section, title: "Safe Title")
    section.leaf.reindex

    leaves = Leaf.search("findme")
    assert_equal "<mark>findme</mark> Tom &amp; Jerry ", leaves.first.content_match
  end

  test "indexing sanitizes section title" do
    section = Section.new(body: "findme content")
    books(:handbook).press(section, title: 'findme Tom & Jerry <img src=x onerror="alert(1)">')
    section.leaf.reindex

    leaves = Leaf.search("findme")
    assert_equal "<mark>findme</mark> Tom &amp; Jerry ", leaves.first.title_match
  end

  test "indexing sanitizes page body" do
    pages(:welcome).update! body: "findme Tom & Jerry <b>bold</b>"

    leaves = Leaf.search("findme")
    assert_equal "<mark>findme</mark> Tom &amp; Jerry bold", leaves.first.content_match
  end


  test "indexing sanitizes page title" do
    leaf = leaves(:welcome_page)
    leaf.update! title: "findme Tom & Jerry <b>bold</b>"
    leaf.reindex

    leaves = Leaf.search("findme")
    assert_equal "<mark>findme</mark> Tom &amp; Jerry bold", leaves.first.title_match
  end

  test "indexing strips injected mark tags from title" do
    section = Section.new(body: "findme content")
    books(:handbook).press(section, title: "findme <mark>fake highlight</mark>")
    section.leaf.reindex

    leaves = Leaf.search("findme")
    assert_equal "<mark>findme</mark> fake highlight", leaves.first.title_match
  end
end
