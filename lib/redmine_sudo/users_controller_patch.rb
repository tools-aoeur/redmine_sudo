# frozen_string_literal: true

module RedmineSudo
  module UsersControllerPatch
    extend ActiveSupport::Concern

    def update_sudoer
      if @user.present? && params[:user][:admin] == '0'
        @user.admin = false
        @user.sudoer = false
      end
    end

  end
end
