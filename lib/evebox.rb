require "pry"
require "eaal"
require_relative "env"

module Evebox
  def self.console!
    setup_tokens!
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
    puts "http://wiki.eve-id.net/APIv2_Page_Index"
  end

  def self.connect_eve(key_id, token)
    EAAL::API.new(key_id, token)
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
  end
end
