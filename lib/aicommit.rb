require_relative "commit/generator"
require_relative "pr/generator"
require_relative "common/utils/ignore_file_checker"
require_relative "common/envs/openai_api_key"
require_relative "common/envs/selected_model"
require_relative "common/envs/base_branch"
require_relative "common/envs/pr_template"
require_relative "common/envs/pr_output_file"
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
  def self.set_openai_api_key(api_key = nil)
    Common::Envs::OpenaiApiKey.new.update!(api_key)
  end

  def self.set_selected_model(model = nil)
    Common::Envs::SelectedModel.new.update!(model)
  end

  def self.set_base_branch(branch = nil)
    Common::Envs::BaseBranch.new.update!(branch)
  end

  def self.set_pr_template(custom_path = nil)
    Common::Envs::PrTemplate.new(custom_path).update!
  end

  def self.set_pr_output_file(filename = nil)
    Common::Envs::PrOutputFile.new.update!(filename)
  end

  # Show current configuration
  def self.show_config
    openai_api_key = Common::Envs::OpenaiApiKey.new.fetch
    selected_model = Common::Envs::SelectedModel.new.fetch
    base_branch = Common::Envs::BaseBranch.new.fetch
    pr_template = Common::Envs::PrTemplate.new.fetch
    pr_output_file = Common::Envs::PrOutputFile.new.fetch

    puts "Current Configuration:".green
    puts "----------------------".green
    puts "OpenAI API Key: #{openai_api_key ? "#{openai_api_key[0, 3]}...#{openai_api_key[-4, 4]}" : "Not set"}"
    puts "Selected Model: #{selected_model || "Not set"}"
    puts "Base Branch: #{base_branch || "Not set"}"
    puts "PR Template: #{pr_template || "Not set"}"
    puts "PR Output File: #{pr_output_file || "Not set"}"
  end

  # Error handling utility
  def self.handle_error(error)
    puts "Error: #{error.message}".red
    exit 1
  end

  # Ensure .env is properly set up in gitignore
  def self.ensure_env_in_ignore_file
    Common::Utils::IgnoreFileChecker.new.ensure_env_in_ignore_file
  end
end
