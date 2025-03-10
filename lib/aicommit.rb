require_relative "commit/generator"
require_relative "pr/generator"
require_relative "common/utils/ignore_file_checker"
require_relative "common/envs/openai_api_key"
require_relative "common/envs/selected_model"
require_relative "common/envs/base_branch"
require_relative "aicommit/version"

module Aicommit
  # Main entry point for the aicommit gem

  # Generate commit message
  def self.run
    Commit::Generator.run
  end

  # Generate PR description
  def self.generate_pr_description(base_ref = nil, options = {})
    PR::Generator.new(base_ref, options).run
  end

  # Environment utilities
  def self.set_openai_api_key
    Common::Envs::OpenaiApiKey.new.update!
  end

  def self.set_selected_model
    Common::Envs::SelectedModel.new.update!
  end

  def self.set_base_branch
    Common::Envs::BaseBranch.new.update!
  end

  # Ensure .env is properly set up in gitignore
  def self.ensure_env_in_ignore_file
    Common::Utils::IgnoreFileChecker.new.ensure_env_in_ignore_file
  end
end
