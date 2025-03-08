require "openai"
require "json"

class AiClient
  DIFF_LIMIT = 1000000

  attr_reader :access_token, :client

  def initialize(access_token = nil)
    @access_token = access_token || Envs::OpenaiApiKey.new.fetch!
    @client = OpenAI::Client.new(access_token: @access_token)
  end

  def get_commit_message(diff)
    messages = set_messages(diff, :commit_message)
    send_message(messages)
  end

  def get_pr_description(diff)
    messages = set_messages(diff, :pr_description)
    send_message(messages)
  end

  def send_message(messages)
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

  def models_list
    safe_api_request { @client.models.list }
  end

  def verify_api_token!
    models_list
  end

  private

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

  def set_messages(diff, type)
    if diff.length > DIFF_LIMIT
      warn_lengthy_diff
    end
    trimmed_diff = (diff.length > DIFF_LIMIT) ? diff[-DIFF_LIMIT..] : diff

    case type
    when :commit_message
      [{role: "user", content: prompt_for_commit_message(trimmed_diff)}]
    when :pr_description
      [{role: "user", content: prompt_for_pr_description(trimmed_diff)}]
    end
  end

  def prompt_for_commit_message(input)
    <<~PROMPT
      Instruction:
      You are an expert developer tasked with generating a concise and informative commit message that clearly describes changes in a given git diff.
      Please analyze the provided diff and generate a commit message that includes a subject and, if necessary, additional description.
      Ensure that the commit message follows standard conventions such as using the imperative mood and being clear for future reference.

      Input:
      #{input}

      Output:
      A well-structured commit message in JSON format that accurately reflects the changes depicted in the diff.
      Only return the JSON object, without any additional text or formatting, that I can parse with ruby's JSON.parse.

      Example:
      {
        "subject": "Add new feature",
        "description": "This commit adds a new feature to the application."
      }
    PROMPT
  end

  def prompt_for_pr_description(input)
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
    puts "This may result in an incomplete or unexpected commit message."
    puts "================================================================="
  end
end
