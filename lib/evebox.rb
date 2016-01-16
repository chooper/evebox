require "pry"
require "eaal"
require "sequel"
require 'logger'
require_relative "evebox/char"
require_relative "env"

module Evebox
  def self.sync!
    setup_tokens!
    db = connect_database
    create_database_tables!(db)
    eve = connect_eve(ENV["EVE_KEY_ID"], ENV["EVE_TOKEN"])

    eve.Characters.characters.map do |eve_char|
      char = Char.new(eve, eve_char.characterID)
      char.save_transactions_to_db(db)
    end
  end

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

      unique      [:characterID, :transactionID]
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
end
