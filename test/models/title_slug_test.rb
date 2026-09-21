require "test_helper"
require_relative "../../db/migrate/20260921120000_repair_empty_book_slugs"

class TitleSlugTest < ActiveSupport::TestCase
  test "titles produce Unicode slugs shared by books and leaves" do
    {
      "Hello, World!" => "hello-world",
      "Куку" => "куку",
      "Привет, мир!" => "привет-мир",
      "English и русский" => "english-и-русский",
      "Cafe\u0301" => "café",
      "--- 😊 !!!" => "-",
      "" => "-",
      "a/b?c#d%20" => "a-b-c-d-20"
    }.each do |title, expected|
      book = books(:handbook)
      book.assign_attributes(title: title, slug: "")
      assert book.valid?
      assert_equal expected, book.slug

      leaf = leaves(:welcome_page)
      leaf.title = title
      assert_equal expected, leaf.slug
    end
  end

  test "renaming a book preserves a nonempty slug" do
    book = books(:handbook)
    book.update!(title: "Новое название")
    assert_equal "handbook", book.reload.slug
  end

  test "migration repairs only empty slugs and is repeatable" do
    book = books(:handbook)
    book.update_columns(title: "Куку", slug: "")
    custom = books(:manual)
    custom.update_columns(title: "Руководство", slug: "custom_slug")

    2.times { RepairEmptyBookSlugs.new.up }
    assert_equal "куку", book.reload.slug
    assert_equal "custom_slug", custom.reload.slug
    RepairEmptyBookSlugs.new.down
    assert_equal "куку", book.reload.slug
  end
end
