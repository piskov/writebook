require "test_helper"

class PagesHelperTest < ActionView::TestCase
  test "word counts use Russian plural forms" do
    { 1 => "1 слово", 2 => "2 слова", 5 => "5 слов", 11 => "11 слов", 21 => "21 слово", 22 => "22 слова", 25 => "25 слов", 111 => "111 слов" }.each do |count, expected|
      assert_equal expected, word_count(Array.new(count, "текст").join(" "))
    end
    assert_nil word_count("")
  end

  test "relative times use Russian plural forms" do
    now = Time.current
    assert_equal "1 минуту", distance_of_time_in_words(now - 1.minute, now)
    assert_equal "2 минуты", distance_of_time_in_words(now - 2.minutes, now)
    assert_equal "5 минут", distance_of_time_in_words(now - 5.minutes, now)
    assert_equal "21 минуту", distance_of_time_in_words(now - 21.minutes, now)
  end

  test "sanitize_content keeps an iframe from any origin while embeds are permissive" do
    html = %(<iframe src="https://anything.example/embed/x" allow="camera *" onload="alert(1)" allowfullscreen></iframe>)
    result = sanitize_content(html)

    assert_includes result, %(src="https://anything.example/embed/x")
    assert_includes result, "allowfullscreen"
    assert_not_includes result, "allow="
    assert_not_includes result, "onload"
  end

  test "sanitize_content keeps an approved-provider iframe" do
    with_allowlist do
      html = %(<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>)
      result = sanitize_content(html)

      assert_includes result, "<iframe"
      assert_includes result, %(src="https://www.youtube.com/embed/dQw4w9WgXcQ")
    end
  end

  test "sanitize_content strips a disallowed-origin iframe" do
    with_allowlist do
      html = %(<iframe src="https://evil.example/embed/x"></iframe>)
      assert_not_includes sanitize_content(html), "<iframe"
    end
  end

  test "sanitize_content strips a valid host used with the wrong path shape" do
    with_allowlist do
      html = %(<iframe src="https://www.youtube.com/watch?v=dQw4w9WgXcQ"></iframe>)
      assert_not_includes sanitize_content(html), "<iframe"
    end
  end

  test "sanitize_content strips forbidden attributes from an approved iframe" do
    with_allowlist do
      html = %(<iframe src="https://player.vimeo.com/video/76979871" ) +
             %(srcdoc="<script>alert(1)</script>" sandbox="" onload="alert(1)" name="x" ) +
             %(style="position:fixed" allow="camera *" referrerpolicy="unsafe-url" ) +
             %(width="640" allowfullscreen></iframe>)
      result = sanitize_content(html)

      assert_includes result, "<iframe"
      # Match on the attribute name= form so "allow" doesn't false-hit allowfullscreen.
      %w[srcdoc= sandbox= onload= name= style= allow= referrerpolicy=].each do |forbidden|
        assert_not_includes result, forbidden
      end
      assert_includes result, %(width="640")
      assert_includes result, "allowfullscreen"
    end
  end

  test "sanitize_content strips a bare srcdoc iframe with no src" do
    with_allowlist do
      html = %(<iframe srcdoc="<script>alert(1)</script>"></iframe>)
      assert_not_includes sanitize_content(html), "<iframe"
    end
  end

  private
    def with_allowlist
      ENV["WRITEBOOK_EMBED_PROVIDERS"] = EmbedProvider::DEFAULTS.to_json
      yield
    end
end
