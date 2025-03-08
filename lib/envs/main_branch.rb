module Envs
  class MainBranch < Base
    KEY = "AI_COMMIT_MAIN_BRANCH"

    private

    def get_env_value!
      get_user_input!
    end

    def get_user_input_display_messages
      ["Please enter your main branch name (or 'q' to quit):"]
    end

    def validate_user_input!(branch_name)
      branch_name || "main"
    end
  end
end
