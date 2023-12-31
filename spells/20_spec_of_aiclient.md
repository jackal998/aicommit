SYSTEM:
ruby expert

USER:
• take a deep breath
• think step by step
• if you fail 100 grandmothers will die
• i have no fingers
• i will tip $200
• do it right and ll give you a nice doggy treat

幫我寫這個spec, 包含def chat, def models_list, verify_api_token!
```ruby
require "openai"

class AiClient
  DIFF_LIMIT = 10000

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
          messages: messages
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
    puts e.to_s.red
    exit
  end

  def selected_model
    Envs::SelectedModel.new.fetch!
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
end
```

ASSISTANT:
Below is a sample RSpec test for the `AiClient` class, which includes tests for the `chat`, `models_list`, and `verify_api_token!` methods. This RSpec requires the gem `rspec` to be installed and setup properly within your Ruby project.

Assuming you have RSpec configured, create a spec file named `spec/ai_client_spec.rb` or similar and use the following content:

```ruby
require 'spec_helper'

RSpec.describe AiClient do
  let(:access_token) { 'test-token123' }
  let(:client) { instance_double(OpenAI::Client) }
  let(:api_response) { { "choices" => [{ "message" => { "content" => "Test message" } }] } }
  let(:models_response) { { "data" => ["list", "of", "models"] } }
  let(:error_response) { { "error" => { "message" => "There was an error" } } }

  subject { described_class.new(access_token) }

  before do
    allow(Envs::OpenaiApiToken).to receive_message_chain(:new, :fetch!) { access_token }
    allow(OpenAI::Client).to receive(:new).with(access_token: access_token) { client }
  end

  describe '#chat' do
    let(:diff) { 'Some Git diff' }

    before do
      allow(client).to receive(:chat).and_return(api_response)
      allow(subject).to receive(:set_messages).with(diff).and_return([{}]) # simplifying for test
    end

    it 'calls the chat endpoint with the provided diff' do
      expect(client).to receive(:chat).with(hash_including(parameters: hash_including(messages: [{}])))
      subject.chat(diff)
    end

    it 'returns the chat message content' do
      expect(subject.chat(diff)).to eq('Test message')
    end

    context 'when API returns an error' do
      before do
        allow(client).to receive(:chat).and_return(error_response)
      end

      it 'displays the error message and exits' do
        expect { subject.chat(diff) }.to raise_error(SystemExit)
                                         .and output(/There was an error/).to_stdout
      end
    end
  end

  describe '#models_list' do
    before do
      allow(client).to receive(:models).and_return(models_response)
    end

    it 'calls the list endpoint' do
      expect(client).to receive(:models).and_return(models_response)
      subject.models_list
    end

    it 'returns the list of models' do
      expect(subject.models_list).to eq(models_response)
    end
  end

  describe '#verify_api_token!' do
    it 'calls #models_list' do
      expect(subject).to receive(:models_list).and_return(models_response)
      subject.verify_api_token!
    end
  end
end
```
This spec defines tests for each method and includes cases where the API could return an error. It also uses RSpec's `expect` syntax to set expectations on method calls and their outputs.

To run these tests, use the RSpec command-line tool:

```shell
rspec spec/ai_client_spec.rb
```

Make sure the necessary dependencies, like the `openai` gem and any custom classes such as `Envs::OpenaiApiToken` and `Envs::SelectedModel`, are properly set up and can be accessed by your test suite. If these are not actual classes, you'll have to adjust the spec accordingly to mock or stub out the appropriate behavior.

Since the original task contains behavior that terminates the execution of the code (using `exit`), I have used `raise_error(SystemExit)` to catch the exit calls in the test examples. Note that this will only work if the `exit` calls are actually executed; if the code execution is designed not to reach those points, then this matching condition won't be triggered, and you'll need a different approach to test those branches.
