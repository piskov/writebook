module PrivateBookAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_private_book_reader, only: :show
  end

  private
    def authenticate_private_book_reader
      return if signed_in? || !request.get? || !request.format.html?

      if Book.where(id: params[:book_id] || params[:id], published: false).exists?
        request_authentication
      end
    end
end
