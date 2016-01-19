require "eaal"
require_relative "char"

module Evebox
  class EveAPI
    def initialize(key_id, token)
      @eaal = EAAL::API.new(key_id, token)
      @characters = []
      load_characters!
    end

    attr_reader :eaal, :characters

    def load_characters!
      @eaal.Characters.characters.map do |c|
        @characters << Char.new(@eaal, c.characterID)
      end
    end
  end
end
