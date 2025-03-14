require_relative "base"

module Common
  module Envs
    class BaseBranch < Base
      KEY = "AI_COMMIT_BASE_BRANCH"

      def update!(provided_value = nil)
        if provided_value
          super(validate_branch_name!(provided_value))
        else
          super
        end
      end

      private

      def get_env_value!
        get_user_input!
      end

      def get_user_input_display_messages
        ["Please enter your base branch name (or 'q' to quit):"]
      end

      def validate_user_input!(branch_name)
        validate_branch_name!(branch_name)
      end

      def validate_branch_name!(branch_name)
        branch_name.to_s.strip.empty? ? "main" : branch_name
      end
    end
  end
end
