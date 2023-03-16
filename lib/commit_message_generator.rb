require "openai"

class CommitMessageGenerator
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
  end

  private

  def set_messages(diff)
    diff = diff[-3800..] || diff
    spell = "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff}"

    [{role: "user", content: spell}]
  end
end
