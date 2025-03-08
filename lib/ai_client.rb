require "openai"
require "json"

class AiClient
  DIFF_LIMIT = 100000

  attr_reader :access_token, :client

  def initialize(access_token = nil)
    @access_token = access_token || Envs::OpenaiApiToken.new.fetch!
    @client = OpenAI::Client.new(access_token: @access_token)
  end

  def get_commit_message(diff)
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

  def warn_lengthy_diff
    puts "================================================================="
    puts "Warning: The Git diff is too lengthy (exceeding the token limit).".yellow
    puts "It may not encompass all file changes."
    puts "This may result in an incomplete or unexpected commit message."
    puts "================================================================="
  end
end
