SYSTEM:
ruby expert

USER:
我想把所有跟`OpenAI::Client`相關的操作都整合到同一個介面，名稱還沒有想好，不過可以參考目前已經寫在`CommitMessageGenerator`裡面的東西
計畫是一個新的物件

粗淺的想法是用以下這些方法，對應不同的流程控制：
- `private def commit_message`
  - 參考目前的`def set_messages(diff)`
- `def chat`
  - 參考目前的`generate(diff)`
- `def models_list`
  - 新的方法，是呼叫`OpenAI::Client.new(access_token: access_token).models.list`
- `def api_token_check`
  - 設計這個方法就是用`OpenAI::Client`檢查api_token，應該是呼叫`models_list`

然後預計會共用一些error_handling, method return value的方法

*這些是我很粗淺的想法，主要就是因為雖然想要把跟`OpenAI::Client`相關的操作都整合到同一個介面
所以需要你幫忙給出架構上的建議，細節跟我的想法都可以調整，以最好維護，最佳可讀性為準，方法名稱，方法結構均可變動

目前的code:
`Envs::OpenaiApiToken`
```ruby
require "openai"

module Envs
  class OpenaiApiToken < Base
    KEY = "OPENAI_API_TOKEN".freeze

    def get
      ENV[KEY] || get_user_input
    end

    def update!
      user_input = get_user_input
      exit unless validate_token!(user_input)

      save_to_env!(KEY, user_input)
      puts "Your OpenAI API token has been saved to .env".green
      user_input
    end

    private

    def get_user_input
      puts "Please enter your OpenAI API token (or 'q' to quit):"
      value = gets.chomp
      exit_if_quit(value)
      value
    end

    def validate_token!(user_input)
      true
    end
  end
end
```
以及`CommitMessageGenerator`
```ruby
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
```

ASSISTANT:
為了整合所有與 `OpenAI::Client` 相關的操作，我們可以創建一個封裝該客戶端邏輯的新類，暫時叫它 `OpenAIInterface`。這個類會管理與 OpenAI API 的交互，包括產生 commit messages、聊天、獲取模型列表以及驗證 API token。

以下是這個新類別的一個草稿示例：

```ruby
require "openai"

class OpenAIInterface
  DIFF_LIMIT = 10000

  attr_reader :access_token, :client

  def initialize(access_token: nil)
    @access_token = access_token || Envs::OpenaiApiToken.new.get
    @client = OpenAI::Client.new(access_token: @access_token)
  end

  def chat(diff)
    messages = set_messages(diff)
    response = safe_api_request do
      @client.chat(
        parameters: {
          model: "gpt-3.5-turbo", # 或許你想從外部動態指定模型
          messages: messages
        }
      )
    end

    response ? { result: response.dig("choices", 0, "message", "content")&.strip, code: response.code } : default_failure
  end

  def models_list
    safe_api_request { @client.models.list }
  end

  def api_token_check
    !models_list.nil?
  end

  private

  def safe_api_request
    yield
  rescue OpenAI::Errors::AuthenticationError
    { error: 'Authentication failed', code: 401 }
  rescue Net::ReadTimeout
    { error: 'API request timed out', code: 500 }
  # You can add more specific error handling here as required.
  end

  def set_messages(diff)
    if diff.length > DIFF_LIMIT
      warn_lengthy_diff
    end
    trimmed_diff = diff.length > DIFF_LIMIT ? diff[-DIFF_LIMIT..] : diff
    prompt = "Please generate a commit message based on the following diff in one sentence and less than 80 letters: \n#{trimmed_diff}"

    [{ role: "user", content: prompt }]
  end

  def warn_lengthy_diff
    puts "================================================================="
    puts "Warning: The Git diff is too lengthy (exceeding the token limit).".yellow
    puts "It may not encompass all file changes."
    puts "This may result in an incomplete or unexpected commit message."
    puts "================================================================="
  end

  def default_failure
    { error: 'An unknown error occurred', code: 500 }
  end
end
```

這個類別的作用是：

- `chat`: 產生 commit messages，相當於原有 `CommitMessageGenerator` 的 `generate` 方法。
- `models_list`: 獲取 OpenAI 可用模型的列表。
- `api_token_check`: 通過嘗試拉取模型列表來確認 API token 是否有效。
- `safe_api_request`: 在這個方法中，我們統一處理了與 OpenAI 客戶端通訊時可能會遇到的任何異常。

在你給出的現有代碼基礎上，我有做一些假設和簡化。例如，我假定你有一個可用的 `Envs::OpenaiApiToken` 類別來獲取 token。此外，我還加入了錯誤處理，並簡化了一些方法的名字以增強可讀性。這種整合方式可以降低與 OpenAI 相關操作的復雜性並提高代碼的可維護性。

在這個例子中，`safe_api_request` 是一個非常有用的抽象，它允許你在一個地方捕獲並處理所有與 OpenAI 通訊相關的錯誤。這裡的錯誤處理是假設性的，你可以根據實際需求擴充它。这个方法使用了 Ruby 的 `yield` 关键词，它允許您传递一个代码块，並在其內部捕獲异常。
