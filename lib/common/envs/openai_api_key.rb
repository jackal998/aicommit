require_relative 'base'
require_relative '../ai_client'

module Common
  module Envs
    class OpenaiApiKey < Base
      KEY = "AI_COMMIT_OPENAI_API_KEY".freeze

      private

      def get_env_value!
        get_user_input!
      end

      def get_user_input_display_messages
        ["Please enter your OpenAI API token (or 'q' to quit):"]
      end

      def validate_user_input!(token)
        Common::AiClient.new(token).verify_api_token!
        token
      end
    end
  end
end
