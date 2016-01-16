require "irb"
require "irb/completion"
require "eaal"
require_relative "env"

def console!
  setup_tokens
  IRB.start
end

def setup_tokens
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

  $eve = EAAL::API.new(ENV["EVE_KEY_ID"], ENV["EVE_TOKEN"])
  puts "Character Name => Character ID"
  $eve.Characters.characters.each { |c| puts "#{c.name} => #{c.characterID}" }
  puts "Welcome to EveBox!"
  puts "API references is at:"
  puts "http://wiki.eve-id.net/APIv2_Page_Index"
end

def character_balances
  chars = $eve.Characters.characters

  $eve.scope = "char"
  balances = {}
  chars.each do |c|
      balances[c.name] = $eve.AccountBalance("characterID" => c.characterID).accounts.select { |a| a.accountKey == "1000" }.first.balance
  end
  balances
end
