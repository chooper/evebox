require "pry"
require "eaal"
require "sequel"
require 'logger'
require_relative "evebox/eveapi"
require_relative "evebox/char"
require_relative "env"

module Evebox
  def self.sync!
    setup_tokens!
    db = connect_database
    create_database_tables!(db)
    eve = EveAPI.new(ENV["EVE_KEY_ID"], ENV["EVE_TOKEN"])

    eve.characters.map do |char|
      char.save_accounts_to_db(db)
      char.save_transactions_to_db(db)
      char.save_journal_to_db(db)
    end
  end

  def self.console!
    setup_tokens!
    db = connect_database
    create_database_tables!(db)

    eve = EveAPI.new(ENV["EVE_KEY_ID"], ENV["EVE_TOKEN"])
    print_connect_banner(eve)
    binding.pry
  end

  def self.print_connect_banner(eve)
    puts "Character Name => Character ID"
    eve.characters.each do |c|
      puts "#{c.character_name} => #{c.character_id}"
    end
    puts "Welcome to EveBox!"
    puts "API references is at:"
    puts "https://eveonline-third-party-documentation.readthedocs.org/en/latest/xmlapi/intro/"
  end

  def self.connect_database
    url = ENV['DATABASE_URL'] || 'sqlite://evebox.sqlite'
    db = Sequel.connect(url, loggers: [Logger.new($stdout)])
    # TODO(charles) split this out
    log_level = ENV['SQL_DEBUG'] || 'debug'
    log_level = log_level.downcase.to_sym
    db.sql_log_level = log_level
    db
  end

  def self.create_database_tables!(db)
    create_account_table!(db)
    create_transaction_table!(db)
    create_journal_table!(db)
  end

  def self.create_account_table!(db)
    db.create_table :wallet_accounts do
      primary_key :eveboxID
      String      :characterID
      String      :characterName
      Time        :date
      String      :accountID
      String      :accountKey
      String      :balance
      unique      [:characterID, :accountID, :date]
    end
    true
  rescue Sequel::DatabaseError, PG::DuplicateTable
    # table probably already existed
    # TODO(charles) log this
    false
  end

  def self.create_journal_table!(db)
    # TODO(charles) set these types correctly
    db.create_table :wallet_journal do
      primary_key :eveboxID
      String      :characterID
      String      :characterName
      String      :date
      String      :refID
      String      :refTypeID
      String      :ownerName1
      String      :ownerID1
      String      :ownerName2
      String      :ownerID2
      String      :argName1
      String      :argID1
      String      :amount
      String      :balance
      String      :reason
      String      :taxReceiverID
      String      :taxAmount
      String      :owner1TypeID
      String      :owner2TypeID

      unique      [:characterID, :refID, :refTypeID]
    end
    true
  rescue Sequel::DatabaseError, PG::DuplicateTable
    # table probably already existed
    # TODO(charles) log this
    false
  end

  def self.create_transaction_table!(db)
    # TODO(charles) set these types correctly
    db.create_table :wallet_transactions do
      primary_key :eveboxID
      String      :characterID
      String      :characterName
      String      :clientID
      String      :clientName
      String      :clientTypeID
      String      :journalTransactionID
      String      :price
      String      :quantity
      String      :stationID
      String      :stationName
      String      :transactionDateTime
      String      :transactionFor
      String      :transactionID
      String      :transactionType
      String      :typeID
      String      :typeName

      unique      [:characterID, :transactionID]
    end
    true
  rescue Sequel::DatabaseError, PG::DuplicateTable
    # table probably already existed
    # TODO(charles) log this
    false
  end

  def self.setup_tokens!
    ENV.source(".env")

    if (ENV["EVE_TOKEN"].nil? or ENV["EVE_TOKEN"].empty?) or (ENV["EVE_KEY_ID"].nil? or ENV["EVE_KEY_ID"].empty?)
      puts "No Eve Token available."
      puts "Please visit the following URL to get a token:"
      puts "https://community.eveonline.com/support/api-key/update/"
      puts ""
      STDOUT.write "Enter the key id here: "
      STDOUT.flush
      key = gets
      if key.empty?
        puts "No key... exiting."
        exit
      end

      STDOUT.write "Enter the token here: "
      STDOUT.flush
      token = gets
      if token.empty?
        puts "No token... exiting."
        exit
      end

      key.chomp!
      token.chomp!
      ENV["EVE_KEY_ID"] = key
      ENV["EVE_TOKEN"] = token
      save_env!
    end
  end
end
