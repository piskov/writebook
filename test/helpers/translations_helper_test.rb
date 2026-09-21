require "test_helper"

class TranslationsHelperTest < ActionView::TestCase
  test "every multilingual hint includes Russian and preserves existing languages" do
    TranslationsHelper::TRANSLATIONS.each_value do |translations|
      assert_equal %i[🇷🇺 🇺🇸 🇪🇸 🇫🇷 🇮🇳 🇩🇪 🇧🇷], translations.keys
      assert_match /[А-Яа-я]/, translations.fetch(:🇷🇺)
    end
  end
end
