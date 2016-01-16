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

    def character_name!
      saved_scope = eve.scope
      eve.scope = 'char'

      args = {
        "characterID" => character_id,
      }

      sheet = eve.CharacterSheet(args)

      eve.scope = saved_scope
      sheet.name
    end

    def transactions
      saved_scope = eve.scope
      eve.scope = 'char'

      args = {
        "characterID" => character_id,
        "rowCount" => 2560}
      t = eve.WalletTransactions(args).transactions

      eve.scope = saved_scope
      t
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
    end
  end
end
