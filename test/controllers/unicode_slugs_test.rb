require "test_helper"

class UnicodeSlugsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :david
    @book = books(:handbook)
    @book.update!(title: "Куку", slug: "")
    @leaf = leaves(:welcome_page)
    @leaf.update!(title: "Привет, мир!")
  end

  test "Unicode book and page URLs render and retain anchors and formats" do
    path = book_slug_path(@book, anchor: "leaf_#{@leaf.id}")
    assert_includes URI::DEFAULT_PARSER.unescape(path), "/куку#leaf_#{@leaf.id}"
    get book_slug_path(@book)
    assert_response :success
    assert_in_body "Куку"

    assert_includes URI::DEFAULT_PARSER.unescape(leafable_slug_path(@leaf)), "/куку/#{@leaf.id}/привет-мир"
    get leafable_slug_path(@leaf)
    assert_response :success
    assert_in_body "a great handbook."
    get leafable_slug_path(@leaf, format: :md)
    assert_response :success
  end

  test "old nonempty and empty slug links still resolve" do
    [ "/#{@book.id}/handbook", "/#{@book.id}/", "/#{@book.id}",
      "/#{@book.id}/handbook/#{@leaf.id}/-", "/#{@book.id}//#{@leaf.id}/-" ].each do |path|
      get path
      assert_response :success
    end
  end

  test "Unicode publication slugs can be edited and unsafe separators are rejected" do
    get edit_book_publication_path(@book)
    assert_response :success
    assert_in_body "Используйте буквы, цифры и дефисы"

    patch book_publication_path(@book), params: { book: { slug: "моя-книга" } }
    assert_redirected_to book_slug_path(@book.reload)
    assert_equal "моя-книга", @book.slug

    [ "a/b", "a?b", "a#b", "a%b", "a b" ].each do |slug|
      patch book_publication_path(@book), params: { book: { slug: slug } }
      assert_response :unprocessable_entity
      assert_equal "моя-книга", @book.reload.slug
    end
  end

  test "anonymous private Unicode page links return to the same URL after login" do
    sign_out
    destination = leafable_slug_path(@leaf, search: "great")
    get destination
    assert_redirected_to new_session_path
    post session_path, params: { email_address: users(:david).email_address, password: "secret123456" }
    assert_redirected_to destination
    follow_redirect!
    assert_response :success
  end
end
