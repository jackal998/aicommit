require "openai"
require "json"
require_relative "envs/base"
require_relative "envs/openai_api_key"
require_relative "envs/selected_model"
require_relative "envs/base_branch"
require_relative "ai_client"
require_relative "git_client"

class PrDescriptionGenerator
  DIFF_LIMIT = 100000

  def initialize(base_ref = nil)
    @git_client = GitClient.new
    @ai_client = AiClient.new
    @base_ref = base_ref
  end

  def run
    base_ref = @base_ref || Envs::BaseBranch.new.fetch!
    diff = git_client.diff_from_branch_root(base_ref)
    pr_description = ai_client.get_pr_description(diff)
    save_pr_description(pr_description)
    puts "PR description has been saved to PR_DESCRIPTION.md"
  end

  private

  attr_reader :git_client, :ai_client

  def save_pr_description(pr_description)
    File.open("PR_DESCRIPTION.md", "w") do |file|
      file.puts "# #{pr_description["title"]}"
      file.puts ""
      file.puts pr_description["description"]
    end
  end
end
