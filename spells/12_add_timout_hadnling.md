Prompt:
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

這是我現在用來得到commit message的class，問題是有時候會出現這個錯誤：
Net::ReadTimeout
我們希望使用者能夠知道發生了什麼事情卻又不會感到突兀，你有什麼修改的建議？

ChatGPT:
當出現Net::ReadTimeout錯誤時，可能是因為API調用時間過長而導致連接超時，因此建議你可以加上錯誤處理的代碼，以便更好地提示使用者發生了什麼事情。

以下是可能的修改建議：

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
  rescue Net::ReadTimeout => e
    {result: e.message, code: 500}
  end

  private

  def set_messages(diff)
    diff = diff[-3800..] || diff
    spell = "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff}"

    [{role: "user", content: spell}]
  end
end


在修改後，當出現Net::ReadTimeout錯誤時，會返回一條錯誤信息，以便讓使用者知道發生了什麼事情，同時不會讓使用者感到突兀。

Prompt:
幫我們也修改一下測試吧：
require "commit_message_generator"

RSpec.describe CommitMessageGenerator do
  let(:access_token) { "test_access_token" }
  let(:client) { instance_double(OpenAI::Client) }
  subject { described_class.new(access_token) }

  before do
    allow(OpenAI::Client).to receive(:new).with(access_token: access_token).and_return(client)
  end

  describe "#generate" do
    let(:diff) { "test diff" }
    let(:response) { OpenStruct.new({"choices" => [{"message" => {"content" => "test message"}}], "code" => 200}) }

    it "returns expected format" do
      allow(client).to receive(:chat).and_return(response)

      expect(subject.generate(diff)).to eq({result: "test message", code: 200})
    end

    context "when diff is less than 3800 chars" do
      let(:diff) { "a" * 1000 }

      it "sends request to OpenAI with all diff" do
        expect(client).to receive(:chat).with(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              {role: "user", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff}"}
            ]
          }
        ).and_return(response)

        subject.generate(diff)
      end
    end

    context "when diff is more than 3800 chars" do
      let(:diff) { "a" * 4000 }

      it "sends request to OpenAI with last 3800 chars" do
        expect(client).to receive(:chat).with(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              {role: "user", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff[-3800..]}"}
            ]
          }
        ).and_return(response)

        subject.generate(diff)
      end
    end
  end
end

ChatGPT:
以下是修改後的測試：

require "commit_message_generator"

RSpec.describe CommitMessageGenerator do
  let(:access_token) { "test_access_token" }
  let(:client) { instance_double(OpenAI::Client) }
  subject { described_class.new(access_token) }

  before do
    allow(OpenAI::Client).to receive(:new).with(access_token: access_token).and_return(client)
  end

  describe "#generate" do
    let(:diff) { "test diff" }
    let(:response) { OpenStruct.new({"choices" => [{"message" => {"content" => "test message"}}], "code" => 200}) }

    it "returns expected format" do
      allow(client).to receive(:chat).and_return(response)

      expect(subject.generate(diff)).to eq({result: "test message", code: 200})
    end

    context "when diff is less than 3800 chars" do
      let(:diff) { "a" * 1000 }

      it "sends request to OpenAI with all diff" do
        expect(client).to receive(:chat).with(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              {role: "user", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff}"}
            ]
          }
        ).and_return(response)

        subject.generate(diff)
      end
    end

    context "when diff is more than 3800 chars" do
      let(:diff) { "a" * 4000 }

      it "sends request to OpenAI with last 3800 chars" do
        expect(client).to receive(:chat).with(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              {role: "user", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff[-3800..]}"}
            ]
          }
        ).and_return(response)

        subject.generate(diff)
      end
    end

    context "when API call times out" do
      let(:diff) { "test diff" }

      it "returns an error message" do
        allow(client).to receive(:chat).and_raise(Net::ReadTimeout)

        expect(subject.generate(diff)).to eq({result: "Net::ReadTimeout", code: 500})
      end
    end
  end
end

在修改後的測試中，我們加入了一個新的測試用例，以測試當API調用超時時，是否能夠返回一條錯誤信息。這樣，當出現Net::ReadTimeout錯誤時，測試也能通過。
