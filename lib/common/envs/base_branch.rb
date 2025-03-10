require_relative "base"

module Common
  module Envs
    class BaseBranch < Base
      KEY = "AI_COMMIT_BASE_BRANCH"

      private

      def get_env_value!
        get_user_input!
      end

      def get_user_input_display_messages
        ["Please enter your base branch name (or 'q' to quit):"]
      end

      def validate_user_input!(branch_name)
        branch_name || "main"
      end
    end
  end
end
