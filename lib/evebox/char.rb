module Evebox
  class Char
    def initialize(eve, character_id)
      @eve = eve
      @character_id = character_id
      @character_name = nil
    end

    attr_reader :eve, :character_id

    def character_name
      @character_name ||= character_name!
    end

    def with_scope(scope)
      saved_scope = eve.scope
      eve.scope = scope

      ret = yield

      eve.scope = saved_scope
      ret
    end

    def character_name!
      with_scope('char') do
        args = {
          "characterID" => character_id,
        }

        sheet = eve.CharacterSheet(args)
        sheet.name
      end
    end

    def journal
      with_scope('char') do
        args = {
          "characterID" => character_id,
          "rowCount" => 2560}
        eve.WalletJournal(args).transactions
      end
    end

    def transactions
      with_scope('char') do
        args = {
          "characterID" => character_id,
          "rowCount" => 2560}
        eve.WalletTransactions(args).transactions
      end
    end

    def wallet_accounts
      with_scope('char') do
        args = {
          "characterID" => character_id}

        eve.AccountBalance(args).accounts
      end
    end

    def market_orders
      with_scope('char') do
        args = {
          "characterID" => character_id}
        eve.MarketOrders(args).orders
      end
    end

    def save_accounts_to_db(db)
      wallet_accounts.each do |a|
        save_account_to_db(db, a)
      end
    end

    def save_account_to_db(db, a)
      a = a.to_hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      a.delete(:attribs)
      a[:characterID] = character_id
      a[:characterName] = character_name
      a[:date] = Time.new.getutc
      db[:wallet_accounts].insert(a)
    rescue Sequel::UniqueConstraintViolation
      nil
    end

    def save_journal_to_db(db)
      journal.each do |j|
        save_journalentry_to_db(db, j)
      end
    end

    def save_journalentry_to_db(db, j)
      j = j.to_hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      j.delete(:attribs)
      j[:characterID] = character_id
      j[:characterName] = character_name
      db[:wallet_journal].insert(j)
    rescue Sequel::UniqueConstraintViolation
      nil
    end

    def save_transactions_to_db(db)
      transactions.each do |t|
        save_transaction_to_db(db, t)
      end
    end

    def save_transaction_to_db(db, t)
      t = t.to_hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      t.delete(:attribs)
      t[:characterID] = character_id
      t[:characterName] = character_name
      db[:wallet_transactions].insert(t)
    rescue Sequel::UniqueConstraintViolation
      nil
    end
  end
end
