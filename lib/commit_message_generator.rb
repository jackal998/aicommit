require "openai"

class CommitMessageGenerator
  DIFF_LIMIT = 10000

  def initialize(access_token)
    @client = OpenAI::Client.new(access_token: access_token)
  end

  def generate(diff)
    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: set_messages(diff)
      }
    )

    {result: response.dig("choices", 0, "message", "content")&.strip, code: response.code}
  rescue Net::ReadTimeout => e
    {result: e.message, code: 500}
  end

  private

  def set_messages(diff)
    if diff.length > DIFF_LIMIT
      puts "================================================================="
      puts "Warning: The Git diff is too lengthy (exceeding the token limit).".yellow
      puts "It may not encompass all file changes."
      puts "This may result in an incomplete or unexpected commit message."
      puts "================================================================="
    end
    diff = diff[-DIFF_LIMIT..] || diff
    spell = "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff}"

    [{role: "user", content: spell}]
  end
end
