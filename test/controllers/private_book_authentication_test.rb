require "test_helper"

class PrivateBookAuthenticationTest < ActionDispatch::IntegrationTest
  test "private books and pages require login and return to the requested URL" do
    destinations.each do |destination|
      get destination
      assert_redirected_to new_session_path
      assert_not_in_body "This is such a great handbook."
      assert_not_in_body books(:handbook).title

      follow_redirect!
      assert_response :success

      post session_path, params: credentials
      assert_redirected_to destination
      follow_redirect!
      assert_response :success
      assert_in_body books(:handbook).title

      delete session_path
    end
  end

  test "failed login preserves the original destination" do
    leaves(:welcome_page).reindex
    destination = leafable_slug_path(leaves(:welcome_page), search: "great")
    get destination
    follow_redirect!

    post session_path, params: credentials.merge(password: "incorrect")
    assert_response :unauthorized

    post session_path, params: credentials
    assert_redirected_to destination
    follow_redirect!
    assert_response :success
    assert_in_body "<mark>great</mark>"
  end

  test "login does not grant book access or cause a login loop" do
    accesses(:kevin_handbook).destroy!

    destinations.each do |destination|
      get destination
      assert_redirected_to new_session_path
      post session_path, params: credentials.merge(email_address: users(:kevin).email_address)
      assert_redirected_to destination
      follow_redirect!
      assert_response :not_found
      delete session_path
    end
  end

  test "public books and pages remain available without login" do
    books(:handbook).update!(published: true)

    destinations.each do |destination|
      get destination
      assert_response :success
    end
  end

  test "missing books are not redirected to login" do
    book_id = Book.maximum(:id) + 1
    get slugged_book_path(id: book_id, slug: "missing")
    assert_response :not_found

    get slugged_leafable_path(book_id: book_id, book_slug: "missing", id: leaves(:welcome_page).id, slug: "missing")
    assert_response :not_found
  end

  test "private markdown responses still return not found" do
    [ book_slug_path(books(:handbook), format: :md), leafable_slug_path(leaves(:welcome_page), format: :md) ].each do |destination|
      get destination
      assert_response :not_found
    end
  end

  test "private background bookmarks and searches still return not found" do
    get book_bookmark_path(books(:handbook))
    assert_response :not_found

    post book_search_path(books(:handbook)), params: { search: "great" }, as: :turbo_stream
    assert_response :not_found
  end

  test "login without a destination returns to the library" do
    get new_session_path
    post session_path, params: credentials
    assert_redirected_to root_path
  end

  private
    def destinations
      [ book_slug_path(books(:handbook)), leafable_slug_path(leaves(:welcome_page), search: "great") ]
    end

    def credentials
      { email_address: users(:david).email_address, password: "secret123456" }
    end
end
