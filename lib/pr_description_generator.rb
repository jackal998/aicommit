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
  DEFAULT_FILENAME = "PR_DESCRIPTION.md"

  def initialize(base_ref = nil, options = {})
    @git_client = GitClient.new
    @ai_client = AiClient.new
    @base_ref = base_ref
    @options = options
  end

  def run
    base_ref = @base_ref || Envs::BaseBranch.new.fetch!
    diff = git_client.diff_from_branch_root(base_ref)
    pr_description = ai_client.get_pr_description(diff)

    output = format_pr_description(pr_description)

    if @options[:file]
      filename = @options[:file].is_a?(String) ? @options[:file] : DEFAULT_FILENAME
      save_to_file(output, filename)
      puts "PR description saved to #{filename}"
    end

    if @options[:clipboard]
      copy_to_clipboard(output)
      puts "PR description copied to clipboard"
    end
  end

  private

  attr_reader :git_client, :ai_client

  def format_pr_description(pr_description)
    "# #{pr_description["title"]}\n\n#{pr_description["description"]}"
  end

  def save_to_file(content, filename)
    File.open(filename, "w") do |file|
      file.puts content
    end
  end

  def copy_to_clipboard(content)
    case RbConfig::CONFIG["host_os"]
    when /darwin/
      IO.popen("pbcopy", "w") { |f| f << content }
    when /linux/
      IO.popen("xclip -selection clipboard", "w") { |f| f << content }
    when /mswin|mingw/
      IO.popen("clip", "w") { |f| f << content }
    else
      puts "Warning: Clipboard functionality not supported on your OS".yellow
    end
  end
end
