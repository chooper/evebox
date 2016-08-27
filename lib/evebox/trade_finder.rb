require 'logger'
require 'json'
require 'faraday'

module Evebox
  module TradeFinder
    MinimumROIForRegionalArbitrage = 0.05

    ItemTypes = {
      34 => "Tritanium",
      35 => "Pyerite",
      36 => "Mexallon",
      37 => "Isogen",
      38 => "Nocxium",
      39 => "Zydrine",
      40 => "Megacyte",
      4051 => "Nitrogen Fuel Block",
      4246 => "Hydrogen Fuel Block",
      4247 => "Helium Fuel Block",
      4312 => "Oxygen Fuel Block",
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

    # Returns the "best" order for given items and direction; specifically:
    # * selects the loweset sell order (direction == :sell)
    # * selects the highest buy order (direction == :buy)
    #
    # Input:
    # * direction (Symbol) :sell or :buy
    # * item_info (Hash) where keys are type names and values are from
    #                    fetch_item_info
    def self.select_top_orders_for_items(direction, item_info)
      # FIXME this is hideous
      if direction == :sell
        select_method = :first
      elsif direction == :buy
        select_method = :last
      else
        raise ArgumentError("direction is expected to be :sell or :buy")
      end

      top_orders = {}
      item_info.keys.each do |type_name|
        top_order = item_info[type_name].sort_by do |hub, market_data|
          market_data[direction.to_s]["fivePercent"]
        end.send(select_method)
        top_orders[type_name] = {
          system:       top_order.first,
          five_percent: top_order.last[direction.to_s]["fivePercent"],
          }
      end
      top_orders
    end

    # Fetch all items' market data from Eve Central
    #
    # Input:
    # * items (Hash) key is type ID, value is type name
    # * systems (Hash) key is system ID, value is system name
    #
    # Returns
    # * (Hash) key is type name, value is another hash
    #   * where key is a system name, value is a struct of market data
    def self.fetch_all_items_market_data(items, systems)
      item_info = {}
      items.each do |type_id, type_name|
        item_info[type_name] = fetch_item_info(type_id, systems)
      end
      item_info
    end

    def self.find_regional_arbitrage
      item_info = fetch_all_items_market_data(ItemTypes, TradeHubSystems)

      # identify lowest sell orders
      lowest_sell_orders = select_top_orders_for_items(:sell, item_info)
      puts "XXX lowest_sell_order: #{lowest_sell_orders.inspect}"

      # identify highest buy orders
      highest_buy_orders = select_top_orders_for_items(:buy, item_info)
      puts "XXX highest_buy_order: #{highest_buy_orders.inspect}"

      # identify quick sales
      lowest_sell_orders.each do |type_name, sell_order|
        buy_order = highest_buy_orders[type_name]
        margin = buy_order[:five_percent] - sell_order[:five_percent]

        # display the quick sale if it has an adequate return on investment
        roi = margin / sell_order[:five_percent]
        if roi > MinimumROIForRegionalArbitrage
          # TODO move the display elsewhere
          puts
          puts "*** Quick Sale opportunity for #{type_name}!"
          puts "*** #{sell_order[:system]} @ #{sell_order[:five_percent]} ISK =>"
          puts "*** #{buy_order[:system]} @ #{buy_order[:five_percent]} ISK>"
          puts "*** Margin: #{margin} ISK (roi = #{roi * 100}%)"
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
