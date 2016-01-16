require "pry"
require "eaal"
require "sequel"
require 'logger'
require_relative "env"

module Evebox
  def self.console!
    setup_tokens!
    db = connect_database
    create_database_tables!(db)

    eve = connect_eve(ENV["EVE_KEY_ID"], ENV["EVE_TOKEN"])
    print_connect_banner(eve)
    chars = Hash[*eve.Characters.characters.map do |c|
      [c.name, Char.new(eve, c.characterID)]
    end.flatten]
    binding.pry
  end

  def self.print_connect_banner(eve)
    puts "Character Name => Character ID"
    eve.Characters.characters.each do |c|
      puts "#{c.name} => #{c.characterID}"
    end
    puts "Welcome to EveBox!"
    puts "API references is at:"
    puts "https://eveonline-third-party-documentation.readthedocs.org/en/latest/xmlapi/intro/"
  end

  def self.connect_eve(key_id, token)
    EAAL::API.new(key_id, token)
  end

=begin
       @transactions=
        [#<CharWalletTransactionsRowsetTransactionsRow:0x007f82d129e798
          @attribs={},
          @clientID="1175337233",
          @clientName="Nero Farway",
          @clientTypeID="1373",
          @container={},
          @journalTransactionID="12052833285",
          @price="817866.00",
          @quantity="3",
          @stationID="60008494",
          @stationName="Amarr VIII (Oris) - Emperor Family Academy",
          @transactionDateTime="2015-12-27 04:14:52",
          @transactionFor="personal",
          @transactionID="4172615769",
          @transactionType="buy",
          @typeID="2404",
          @typeName="Light Missile Launcher II">,
=end

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
    end
    true
  rescue Sequel::DatabaseError
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

  class Char
    def initialize(eve, character_id)
      @eve = eve
      @character_id = character_id
    end

    attr_reader :eve, :character_id

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
      puts "XXX #{t}"
      db[:wallet_transactions].insert(t)
    end
  end
end
