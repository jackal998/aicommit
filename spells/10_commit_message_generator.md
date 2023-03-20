Prompt:
你好，現在我有一個gem 的主程式如下：
require "git"
require "openai"
require_relative "token_manager"
require_relative "git_client"

class Aicommit
  def initialize
    @token_manager = TokenManager.new
  end

  def run
    patch_diffs = git_client.get_patch_str

    commit_message = generate_commit_message(patch_diffs)

    loop do
      puts "commit_message: #{commit_message}"
      puts "Do you want to keep this commit_message? (Y/N) (or Q to quit)"
      command = gets.chomp
      if command.match?(/^[Yy]$/)
        git_client.commit_all(commit_message)
        puts "Committed all changes with message: #{commit_message}"
        break
      elsif command.match?(/^[Nn]$/)
        puts "Please enter your new commit_message:"
        commit_message = gets.chomp
      elsif command.match?(/^[Qq]$/)
        puts "Quit without committing."
        exit
      else
        puts "Invalid command. Please enter Y, N, or Q."
      end
    end
  end

  private

  def generate_commit_message(diff)
    diff = diff[-3800..] || diff
    client = OpenAI::Client.new(access_token: @token_manager.fetch("OPENAI_API_TOKEN"))
    content = "Please generate a commit message based on the following diff in one sentance and less than 80 letters:\n#{diff}"

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [{role: "user", content: content}]
      }
    )

    if response.code == 401
      puts "Invalid API key."
      @token_manager.write!("OPENAI_API_TOKEN")

      return generate_commit_message(diff)
    end

    response.dig("choices", 0, "message", "content").strip
  end

  def git_client
    @_git_client ||= GitClient.new
  end
end

我想要把方法 :generate_commit_message 打包成一個物件，讓這個物件有一個方法
，將OpenAI::Client 得到的結果打包成以下格式 { result: response.dig....., code: response.code }，token 會從外部傳進來，不希望有recursive 的情境
請問我該怎麼做？

ChatGPT:
好的，讓我來幫你設計一個物件來包裝 `generate_commit_message` 方法。

首先，我們可以建立一個名為 `CommitMessageGenerator` 的類別，然後在初始化方法中接收 `access_token` 參數，以及初始化 `OpenAI::Client` 物件。

接下來，我們可以建立一個名為 `generate` 的方法，讓外部可以呼叫這個方法來執行 `generate_commit_message` 方法。在 `generate` 方法中，我們可以直接呼叫 `generate_commit_message` 方法並且回傳一個包含 `result` 和 `code` 的 Hash 物件。

最後，為了避免 recursive 的情況，我們可以將 `generate_commit_message` 方法中的 `@token_manager` 參數改為由外部傳入，而不是在初始化方法中建立，避免物件之間互相呼叫而導致遞迴。

以下是修改後的程式碼：

```ruby
require "openai"

class CommitMessageGenerator
  def initialize(access_token)
    @client = OpenAI::Client.new(access_token: access_token)
  end

  def generate(diff, token)
    diff = diff[-3800..] || diff
    content = "Please generate a commit message based on the following diff in one sentance and less than 80 letters:\n#{diff}"

    response = @client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [{role: "user", content: content}]
      }
    )

    if response.code == 401
      puts "Invalid API key."
      return { result: nil, code: response.code }
    end

    { result: response.dig("choices", 0, "message", "content").strip, code: response.code }
  end
end
```

現在我們可以在 `Aicommit` 類別中，建立一個 `CommitMessageGenerator` 物件，並將 `generate_commit_message` 方法改成使用 `CommitMessageGenerator` 物件。修改後的程式碼如下：

```ruby
require "git"
require_relative "token_manager"
require_relative "git_client"
require_relative "commit_message_generator"

class Aicommit
  def initialize
    @token_manager = TokenManager.new
    @commit_message_generator = CommitMessageGenerator.new(@token_manager.fetch("OPENAI_API_TOKEN"))
  end

  def run
    patch_diffs = git_client.get_patch_str

    commit_message = @commit_message_generator.generate(patch_diffs, @token_manager.fetch("OPENAI_API_TOKEN"))[:result]

    loop do
      puts "commit_message: #{commit_message}"
      puts "Do you want to keep this commit_message? (Y/N) (or Q to quit)"
      command = gets.chomp
      if command.match?(/^[Yy]$/)
        git_client.commit_all(commit_message)
        puts "Committed all changes with message: #{commit_message}"
        break
      elsif command.match?(/^[Nn]$/)
        puts "Please enter your new commit_message:"
        commit_message = gets.chomp
      elsif command.match?(/^[Qq]$/)
        puts "Quit without committing."
        exit
      else
        puts "Invalid command. Please enter Y, N, or Q."
      end
    end
  end

  private

  def git_client
    @_git_client ||= GitClient.new
  end
end
```

這樣修改後，`generate_commit_message` 方法的功能被包裝成一個獨立的物件，可以更方便地呼叫。同時，我們也順便解決了遞迴的問題。

Prompt:
我參照你的建議新增了以下檔案 commit_message_generator.rb
```
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
    spell = "Please generate a commit message based on the following diff in one sentance and less than 80 letters"

    [{role: "system", content: spell}, {role: "user", content: diff}]
  end
end
```
我現在設計好測試用的spec 了，想請你幫忙完成
```
require "commit_message_generator"

RSpec.describe CommitMessageGenerator do
  describe "#generate" do
    it "returns expected format" do
    end

    context "when diff is less than 3800 chars" do
      it "send request to open ai with all diff" do
      end
    end

    context "when diff is more than 3800 chars" do
      it "send request to open ai with last 3800 chars" do
      end
    end
  end
end
```

ChatGPT:
好的，以下是幫你完成的 spec：

```ruby
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
    let(:response) { { "choices" => [{ "message" => { "content" => "test message" } }], "code" => 200 } }

    it "returns expected format" do
      allow(client).to receive(:chat).and_return(response)

      expect(subject.generate(diff)).to eq({ result: "test message", code: 200 })
    end

    context "when diff is less than 3800 chars" do
      let(:diff) { "a" * 1000 }

      it "sends request to OpenAI with all diff" do
        expect(client).to receive(:chat).with(
          parameters: {model: "gpt-3.5-turbo",
            messages: [
              { role: "system", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters" },
              { role: "user", content: diff }
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
              { role: "system", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters" },
              { role: "user", content: diff[-3800..-1] }
            ]
          }
        ).and_return(response)

        subject.generate(diff)
      end
    end
  end
end
```

這個 spec 包含了三個測試案例。第一個測試確認 `generate` 方法的回傳格式是否正確。第二個測試確認當 diff 長度小於 3800 時，是否會傳送完整的 diff 給 OpenAI。第三個測試則確認當 diff 長度大於 3800 時，是否會只傳送最後 3800 個字元給 OpenAI。

在測試中，我們使用了 instance_double 和 allow 方法來模擬 OpenAI::Client 的行為，並且使用 expect 方法來確認是否正確呼叫了 chat 方法以及傳送了正確的參數。
