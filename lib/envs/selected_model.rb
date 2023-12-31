module Envs
  class SelectedModel < Base
    KEY = "SELECTED_MODEL".freeze
    ALLOWED_OWNERS = ["openai", "system"].freeze
    DISALLOED_TYPES = ["vision", "instruct"].freeze
    ALLOWED_ID_PREFIX = "gpt".freeze

    private

    def get_env_value!
      models_list[get_user_input!.to_i - 1]
    end

    def models_list
      @_models_list ||=
        AiClient.new.models_list["data"].reduce([]) do |array, model|
          model_allowed?(model) ? array << model["id"] : array
        end.sort.reverse
    end

    def model_allowed?(model)
      model["id"].start_with?(ALLOWED_ID_PREFIX) &&
        ALLOWED_OWNERS.include?(model["owned_by"]) &&
        !DISALLOED_TYPES.any? { |type| model["id"].include?(type) }
    end

    def get_user_input_display_messages
      ["Please select a model: (1-#{models_list.size})"].tap do |display_messages|
        models_list.each_with_index do |item, index|
          display_messages << "#{index + 1}. #{item}"
        end
      end
    end

    def validate_user_input!(user_input)
      unless [*(1..models_list.size)].include?(user_input.to_i)
        puts "Invalid selection, exiting program."
        exit
      end
    end
  end
end
