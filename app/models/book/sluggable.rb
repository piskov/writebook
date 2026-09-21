module Book::Sluggable
  extend ActiveSupport::Concern

  included do
    before_validation :generate_slug, if: -> { slug.blank? }
    validates :slug, format: { with: /\A[\p{L}\p{M}\p{N}-]+\z/ }, if: :will_save_change_to_slug?
  end

  def generate_slug
    self.slug = TitleSlug.generate(title)
  end
end
