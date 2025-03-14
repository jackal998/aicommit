require_relative "base"
require_relative "../git_client"

module Common
  module Envs
    class BaseBranch < Base
      KEY = "AI_COMMIT_BASE_BRANCH"
      DEFAULT_BRANCH = "main"

      def update!(provided_value = nil)
        if provided_value
          validated_branch = validate_branch_name!(provided_value)
          return nil unless validated_branch
          super(validated_branch)
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
        # Use default branch for empty input
        branch_to_check = branch_name.to_s.strip.empty? ? DEFAULT_BRANCH : branch_name
        
        # Validate the branch exists
        git_client = Common::GitClient.new
        
        unless git_client.branch_exists?(branch_to_check)
          puts "Error: Branch '#{branch_to_check}' does not exist in this repository.".red
          puts "Please enter a valid branch name or commit SHA.".yellow
          return nil
        end
        
        branch_to_check
      end
    end
  end
end
