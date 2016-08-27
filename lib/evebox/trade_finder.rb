require 'logger'
require 'json'
require 'faraday'

module Evebox
  module TradeFinder
    ItemTypes = {
      34 => "Tritanium",
      35 => "Pyerite",
      36 => "Mexallon",
      37 => "Isogen",
      38 => "Nocxium",
      39 => "Zydrine",
      40 => "Megacyte",
      29668 => "PLEX",
      16274 => "Helium Isotopes",
      17889 => "Hydrogen Isotopes",
      17888 => "Nitrogen Isotopes",
      17887 => "Oxygen Isotopes"
    }

    TradeHubSystems = {
      "30000142" => "Jita",
      "30002659" => "Dodixie",
      "30002510" => "Rens",
      "30002187" => "Amarr",
      "30002053" => "Hek"
    }

    def self.logger
      @@logger ||= Logger.new($stdout)
    end

    def self.find_regional_arbitrage
      item_info = {}
      ItemTypes.each do |type_id, type_name|
        item_info[type_name] = fetch_item_info(type_id, TradeHubSystems)
      end

      # identify lowest sell orders
      lowest_sell_orders = {}
      item_info.keys.each do |type_name|
        lowest_sell_order = item_info[type_name].sort_by do |hub, market_data|
          market_data["sell"]["fivePercent"]
        end.first
        lowest_sell_orders[type_name] = {
          system:       lowest_sell_order.first,
          five_percent: lowest_sell_order.last["sell"]["fivePercent"],
          }
      end
      puts "XXX lowest_sell_order: #{lowest_sell_orders.inspect}"

      # identify highest buy orders
      highest_buy_orders = {}
      item_info.keys.each do |type_name|
        highest_buy_order = item_info[type_name].sort_by do |hub, market_data|
          market_data["buy"]["fivePercent"]
        end.last
        highest_buy_orders[type_name] = {
          system:       highest_buy_order.first,
          five_percent: highest_buy_order.last["buy"]["fivePercent"],
          }
      end
      puts "XXX highest_buy_order: #{highest_buy_orders.inspect}"

      # identify quick sales
      lowest_sell_orders.each do |type_name, sell_order|
        buy_order = highest_buy_orders[type_name]
        margin = buy_order[:five_percent] - sell_order[:five_percent]

        # display the quick sale if it has a positive margin
        if margin > 0 # TODO base on percentage or something
          puts
          puts "*** Quick Sale opportunity for #{type_name}!"
          puts "*** #{sell_order[:system]} @ #{sell_order[:five_percent]} ISK =>"
          puts "*** #{buy_order[:system]} @ #{buy_order[:five_percent]} ISK>"
          puts "*** Margin: #{margin} ISK"
          puts
        end
      end
      nil
    end

    # Fetches market data for a given item type from Eve Central
    # https://www.eve-central.com/home/develop.html
    #
    # Input:
    # * type_id (Integer) The Eve Online ID for the item type
    # * systems (Array<String>) The Eve Online ID for the system;
    #                           Eve Central will expect a String representing
    #                           an integer
    def self.fetch_item_info(type_id, systems)
      conn = Faraday.new(:url => 'http://api.eve-central.com') do |faraday|
        faraday.request  :url_encoded             # form-encode POST params
        faraday.response :logger                  # log requests to STDOUT
        faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      end

      # Iterate through each of the given systems and fetch the item's market
      # data for them
      system_info = {}
      systems.each do |system_id, system_name|
        resp = conn.post '/api/marketstat/json', {
          :usesystem  => system_id,
          :typeid     => type_id
        }
        system_info[system_name] = JSON.parse(resp.body).first

        # clean up some structs we don't need
        system_info[system_name]["buy"].delete("forQuery")
        system_info[system_name]["all"].delete("forQuery")
        system_info[system_name]["sell"].delete("forQuery")
      end
      system_info
    end
  end
end
