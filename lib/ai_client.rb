require "openai"

class AiClient
  DIFF_LIMIT = 100000

  attr_reader :access_token, :client

  def initialize(access_token = nil)
    @access_token = access_token || Envs::OpenaiApiToken.new.fetch!
    @client = OpenAI::Client.new(access_token: @access_token)
  end

  def chat(diff)
    messages = set_messages(diff)
    response = safe_api_request do
      @client.chat(
        parameters: {
          model: selected_model,
          messages: messages,
          temperature: 0.7
        }
      )
    end

    response.dig("choices", 0, "message", "content")&.strip&.delete("\"")
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
      You are an expert developer tasked with generating a concise and informative commit message that clearly describes changes in a given git diff. Please analyze the provided diff and generate a commit message that includes a summary (title) and, if necessary, additional details. Ensure that the commit message follows standard conventions such as using the imperative mood and being clear for future reference.

      Input:
      #{input}

      Output:
      A well-structured commit message that accurately reflects the changes depicted in the diff.
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
