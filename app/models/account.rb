class Account < ApplicationRecord
    has_many :transactions
    validates :name, uniqueness: true
    validates :name, :category, presence: true
    after_save :check_suspension

    def deposits
        self.transactions.where(category: 'Deposit')
    end

    def withdraws
        self.transactions.where(category: 'Withdraw')
    end

    def overdrafts
        self.transactions.where(category: 'Overdraft')
    end

    def deposit(amount)
        return if amount_is_not_valid(amount)

        ActiveRecord::Base.transaction do
            self.update!(balance: self.balance + amount)
            Transaction.create!(amount: amount, category: 'Deposit', account_id: self.id)
        end
    end
    
    def withdraw(amount)
        return if amount_is_not_valid(amount)
        return if account_is_suspended

        if self.balance >= amount
            ActiveRecord::Base.transaction do
                self.update!(balance: self.balance - amount)
                Transaction.create!(amount: amount, category: 'Withdraw', account_id: self.id)
            end
        else
            ActiveRecord::Base.transaction do
                fee = 50
                self.update!(balance: self.balance - fee, flags: self.flags + 1)
                Transaction.create!(amount: fee, category: 'Overdraft', account_id: self.id)
            end
        end
    end
    
    def clear_suspension
        return if insufficient_funds

        ActiveRecord::Base.transaction do
            fee = 100
            self.update!(balance: self.balance - fee, is_suspended: false)
            Transaction.create!(amount: fee, category: 'Unfreeze', account_id: self.id)
        end
    end

    private
    
    def check_suspension
        if self.flags > 3
            self.update!(is_suspended: true, flags: 0)
        end
    end

    def insufficient_funds
        self.errors.add(:balance, 'does not have sufficient funds') if self.balance < 100
        self.errors.any?
    end

    def account_is_suspended
        self.errors.add(:account, 'is suspended due to overdrafts') if self.is_suspended
        self.errors.any?
    end

    def amount_is_not_valid(amount)
        if !amount.is_a? Numeric
            self.errors.add(:amount, 'not a number') 
            return
        end

        self.errors.add(:amount, 'less than zero') if amount <= 0
        self.errors.any?
    end
end