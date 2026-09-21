# Load the rule with the locale so it survives I18n.backend.reload!.
{
  ru: {
    i18n: {
      plural: {
        rule: ->(count) {
          if count % 10 == 1 && count % 100 != 11
            :one
          elsif (2..4).cover?(count % 10) && !(12..14).cover?(count % 100)
            :few
          elsif count % 10 == 0 || (5..9).cover?(count % 10) || (11..14).cover?(count % 100)
            :many
          else
            :other
          end
        }
      }
    }
  }
}
