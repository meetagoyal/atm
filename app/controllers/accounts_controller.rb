class AccountsController < ApplicationController
    def index
        @accounts = Account.order(id: :desc)
    end
end