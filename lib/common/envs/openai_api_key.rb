require_relative "base"
require_relative "../ai_client"

module Common
  module Envs
    class OpenaiApiKey < Base
      KEY = "AI_COMMIT_OPENAI_API_KEY".freeze

      def update!(provided_value = nil)
        if provided_value
          validated_key = validate_token!(provided_value)
          # Only proceed with update if validation passed
          return nil unless validated_key
          super(validated_key)
        else
          super
        end
      end

      private

      def get_env_value!
        get_user_input!
      end

      def get_user_input_display_messages
        ["Please enter your OpenAI API token (or 'q' to quit):"]
      end

      def validate_user_input!(token)
        validate_token!(token)
      end

      def validate_token!(token)
        unless Common::AiClient.new(token).verify_api_token!
          puts "The API key could not be verified. Please check your key and try again.".red
          return nil
        end
        
        token
      end
    end
  end
end
