module Envs
  class OpenaiApiToken < Base
    KEY = "OPENAI_API_TOKEN".freeze

    private

    def get_env_value!
      get_user_input!
    end

    def get_user_input_display_messages
      ["Please enter your OpenAI API token (or 'q' to quit):"]
    end

    def validate_user_input!(token)
      AiClient.new(token).verify_api_token!
    end
  end
end
