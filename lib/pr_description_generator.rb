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

  def initialize
    @git_client = GitClient.new
    @access_token = Envs::OpenaiApiKey.new.fetch!
    @client = OpenAI::Client.new(access_token: @access_token)
  end

  def run
    base_branch = Envs::BaseBranch.new.fetch!
    diff = @git_client.diff_from_branch_root(base_branch)
    pr_description = generate_pr_description(diff)

    loop do
      puts "Generated PR Description:\n\n"
      puts pr_description["title"]
      puts "\n"
      puts pr_description["description"]
      puts "\n"
      puts "Do you want to keep this PR description? (Y/R/N) (or Q to quit)"

      case gets.chomp
      when /^[Yy]$/
        save_pr_description(pr_description)
        puts "PR description has been saved to PR_DESCRIPTION.md"
        exit
      when /^[Rr]$/
        puts "Regenerating..."
        puts ""
        pr_description = generate_pr_description(diff)
      when /^[Nn]$/
        puts "Please enter your custom PR title:"
        title = gets.chomp
        puts "Please enter your custom PR description (end with a line containing only 'END'):"
        description_lines = []
        loop do
          line = gets.chomp
          break if line == "END"
          description_lines << line
        end
        pr_description = {
          "title" => title,
          "description" => description_lines.join("\n")
        }
      when /^[Qq]$/
        puts "Quit without saving PR description."
        exit
      else
        puts "Invalid command. Please enter Y, R, N, or Q."
        puts ""
      end
    end
  end

  private

  def generate_pr_description(diff)
    messages = set_messages(diff)
    response = safe_api_request do
      @client.chat(
        parameters: {
          model: selected_model,
          response_format: {type: "json_object"},
          messages: messages,
          temperature: 0.7
        }
      )
    end

    JSON.parse(response.dig("choices", 0, "message", "content"))
  end

  def save_pr_description(pr_description)
    File.open("PR_DESCRIPTION.md", "w") do |file|
      file.puts "# #{pr_description["title"]}"
      file.puts ""
      file.puts pr_description["description"]
    end
  end

  def safe_api_request
    response = yield
    return response if response["error"].nil?

    puts response.dig("error", "message").red
    exit
  rescue Net::ReadTimeout
    puts "API request timed out".red
    exit
  rescue => e
    puts e.response&.dig(:body, "error", "message").to_s.red
    exit
  end

  def selected_model
    Envs::SelectedModel.new.fetch!
  end

  def set_messages(diff)
    if diff.length > DIFF_LIMIT
      warn_lengthy_diff
    end
    trimmed_diff = (diff.length > DIFF_LIMIT) ? diff[-DIFF_LIMIT..] : diff

    [{role: "user", content: prompt(trimmed_diff)}]
  end

  def prompt(input)
    <<~PROMPT
      Instruction:
      You are an expert developer tasked with generating a well-structured PR (Pull Request) description in markdown format based on a git diff.
      Please analyze the provided diff and generate a PR description that includes:

      1. A clear and concise PR title
      2. A detailed description that covers:
         - Purpose of the changes
         - Summary of the main implementation details
         - Any important technical decisions or trade-offs
         - Related issues or tickets (if apparent from the code)

      Ensure the PR description is well-formatted with proper markdown syntax (headings, bullet points, code blocks, etc.).

      Input:
      #{input}

      Output:
      A well-structured PR description in JSON format that accurately describes the changes in the diff.
      Only return the JSON object, without any additional text or formatting, that I can parse with ruby's JSON.parse.

      Example:
      {
        "title": "Implement user authentication system",
        "description": "## Overview\\nThis PR implements the user authentication system using JWT tokens.\\n\\n## Changes\\n- Add User model with secure password storage\\n- Implement sign up and login endpoints\\n- Add JWT token generation and validation\\n- Update middleware to handle authentication\\n\\n## Technical Details\\nThe implementation uses bcrypt for password hashing and JWT for session management.\\n\\n## Testing\\nMigrations and tests have been added to verify the functionality."
      }
    PROMPT
  end

  def warn_lengthy_diff
    puts "================================================================="
    puts "Warning: The Git diff is too lengthy (exceeding the token limit).".yellow
    puts "It may not encompass all file changes."
    puts "This may result in an incomplete or unexpected PR description."
    puts "================================================================="
  end
end
