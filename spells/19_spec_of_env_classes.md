SYSTEM:
ruby expert

USER:
• take a deep breath
• think step by step
• if you fail 100 grandmothers will die
• i have no fingers
• i will tip $200
• do it right and ll give you a nice doggy treat

幫我寫這個spec, 包含def fetch, def fetch!, update!
```ruby
module Envs
  class OpenaiApiToken < Base
    KEY = "OPENAI_API_TOKEN".freeze

    private

    def get_env_value!
      get_user_input!
    end

    def get_user_input_display_messages
      ["Please enter your OpenAI API token (or 'q' to quit):"]
    end

    def validate_user_input!(token)
      AiClient.new(token).verify_api_token!
    end
  end
end
```

```ruby
require "dotenv"

module Envs
  class Base
    ENV_PATH = "#{File.expand_path("../..", __FILE__)}/.env".freeze

    def initialize
      Dotenv.load(ENV_PATH)
    end

    def fetch
      ENV[self.class::KEY]
    end

    def fetch!
      ENV[self.class::KEY] || get_env_value!
    end

    def update!
      env_value = get_env_value!
      save_to_env!(self.class::KEY, env_value)
      puts "saved to .env".green
      env_value
    end

    private

    def get_env_value!
      raise NotImplementedError
    end

    def get_user_input!
      get_user_input_display_messages.each { |msg| puts msg }
      user_input = gets.chomp
      exit_if_quit!(user_input)

      validate_user_input!(user_input)
      user_input
    end

    def validate_user_input!(user_input)
      raise NotImplementedError
    end

    def save_to_env!(env_key, value)
      File.write(ENV_PATH, updated_env_contents(env_key, value))

      Dotenv.overload!(ENV_PATH)
    end

    def updated_env_contents(env_key, value)
      env_contents = File.exist?(ENV_PATH) ? File.read(ENV_PATH) : ""
      env_contents.tap do |str|
        str.sub!(/^#{Regexp.escape(env_key)}=.*$/, '') # 移除舊有的 env_key
        str.strip!
        str << "\n" unless env_contents.empty? || env_contents.end_with?("\n")
        str << "#{env_key}=#{value}\n"
      end
    end

    def exit_if_quit!(input)
      if input.to_s.downcase == "q"
        puts "Exiting program."
        exit
      end
    end
  end
end
```

ASSISTANT:
To create a spec for the provided classes `Envs::OpenaiApiToken` and `Envs::Base`, we'll use RSpec, a behavior-driven development (BDD) tool for Ruby. Our spec will need to test the main functionalities such as fetching, forcefully fetching, and updating the OpenAI API token in the `.env` file.

Let's break down the actions in the spec we're going to write:

- `fetch`: Should simply return the value from the environment without modification.
- `fetch!`: Should return the value from the environment or prompt the user for input if it's missing.
- `update!`: Should get user input, validate it, then write the update to the `.env` file.

Here's a hypothetical spec that you could write for this scenario:

```ruby
require 'spec_helper'

RSpec.describe Envs::OpenaiApiToken do
  let(:api_token) { 'sample_token' }
  let(:ai_client) { instance_double('AiClient') }
  let(:env_path) { described_class::ENV_PATH }
  let(:existing_env_content) { "#{described_class::KEY}=old_token" }

  before do
    allow(File).to receive(:expand_path).and_return('/fakepath')
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
  end

  describe '#fetch' do
    it 'returns the existing value from ENV without prompting' do
      stub_const('ENV', described_class::KEY => api_token)
      token_fetcher = described_class.new
      expect(token_fetcher.fetch).to eq(api_token)
    end

    context 'when the value does not exist' do
      it 'returns nil' do
        stub_const('ENV', {})
        token_fetcher = described_class.new
        expect(token_fetcher.fetch).to be_nil
      end
    end
  end

  describe '#fetch!' do
    it 'returns the existing value without prompting' do
      stub_const('ENV', described_class::KEY => api_token)
      token_fetcher = described_class.new
      expect(token_fetcher.fetch!).to eq(api_token)
    end

    it 'prompts the user when the value is not set' do
      stub_const('ENV', {})
      token_fetcher = described_class.new

      expect(token_fetcher).to receive(:get_env_value!).and_return(api_token)
      expect(token_fetcher.fetch!).to eq(api_token)
    end
  end

  describe '#update!' do
    before do
      allow(File).to receive(:read).and_return(existing_env_content)
      allow(File).to receive(:write)
      allow(token_fetcher).to receive(:gets).and_return(api_token)
      allow(AiClient).to receive(:new).with(api_token).and_return(ai_client)
      allow(ai_client).to receive(:verify_api_token!).and_return(true)
    end

    let(:token_fetcher) { described_class.new }

    it 'prompts the user for input, validates and saves token to the env file' do
      expect(token_fetcher).to receive(:puts).with("saved to .env").and_call_original
      token_fetcher.update!
      expect(File).to have_received(:write).with(
        env_path,
        /\A#{described_class::KEY}=#{api_token}\n\Z/
      )
    end
  end
end
```

This spec tests the main functionalities of `Envs::OpenaiApiToken`. Here are some key points:

- We're using `instance_double` to create a double of the `AiClient` class that will be used to verify the API token without hitting a real API.
- We use `stub_const` to make sure the `ENV` contains the appropriate data for the tests.
- We mock and stub the file operations like read and write as well as the user input to avoid any real IO during the tests.
- The spec assumes that the `AiClient` class has a `#verify_api_token!` method.

Please remember to include your spec helper and set up RSpec accordingly to your project's specifications.

Keep in mind that while I've outlined a general approach to writing this spec, there are many ways it could fail, including but not limited to inaccuracies in how the production code behaves, how the stubbing and mocking is set up, and other edge cases that may arise. So make sure to run your tests and refine the specifics as per your codebase's implementations and needs.

USER:
請用一樣的方式寫這個：
```ruby
module Envs
  class SelectedModel < Base
    KEY = "SELECTED_MODEL".freeze
    ALLOWED_OWNERS = ["openai", "system"].freeze
    DISALLOED_TYPES = ["vision", "instruct"].freeze
    ALLOWED_ID_PREFIX = "gpt".freeze

    private

    def get_env_value!
      models_list[get_user_input!.to_i - 1]
    end

    def models_list
      @_models_list ||=
        AiClient.new.models_list["data"].filter_map do |model|
          model["id"] if allowed_model(model)
        end.sort.reverse
    end

    def allowed_model(model)
      model["id"].start_with?(ALLOWED_ID_PREFIX) &&
        ALLOWED_OWNERS.include?(model["owned_by"]) &&
        !DISALLOED_TYPES.any? { |type| model["id"].include?(type) }
    end

    def get_user_input_display_messages
      ["Please select a model: (1-#{models_list.size})"].tap do |display_messages|
        models_list.each_with_index do |item, index|
          display_messages << "#{index + 1}. #{item}"
        end
      end
    end

    def validate_user_input!(user_input)
      unless [*(1..models_list.size)].include?(user_input.to_i)
        puts "Invalid selection, exiting program."
        exit
      end
    end
  end
end
```

ASSISTANT:
To write a spec for the `Envs::SelectedModel` class, we'll follow a similar pattern to what we used for the `Envs::OpenaiApiToken` class, adapting the tests to the specifics of the `SelectedModel` class. Remember that this walkthrough assumes that you have an `AiClient` class with a `#models_list` method that returns a hash with a key `"data"` containing an array of model hashes.

```ruby
require 'spec_helper'

RSpec.describe Envs::SelectedModel do
  # Model information that the AiClient would provide
  let(:model_data) do
    [
      { "id" => "gpt-3.5-turbo", "owned_by" => "openai" },
      { "id" => "gpt-3-abc", "owned_by" => "openai" },
      { "id" => "vision-model", "owned_by" => "system" },
      { "id" => "gpt-2.5-instruct", "owned_by" => "openai" }
      # ... other models
    ]
  end

  let(:ai_client) { instance_double('AiClient') }
  let(:env_path) { described_class::ENV_PATH }
  let(:existing_env_content) { "#{described_class::KEY}=old_model" }

  # Assume that 'ENV' and 'File' have been correctly stubbed
  before do
    allow(File).to receive(:expand_path).and_return('/fakepath')
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
    allow(AiClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:models_list).and_return({ "data" => model_data })
  end

  describe '#fetch!' do
    let(:model_selector) { described_class.new }

    it 'prompts the user and returns the selected model' do
      allow(model_selector).to receive(:gets).and_return("2\n") # user selects the second model
      expect(model_selector.fetch!).to eq(model_data[1]["id"])
    end

    it 'exits the program if an invalid selection is made' do
      allow(model_selector).to receive(:gets).and_return("10\n") # invalid selection
      expect { model_selector.fetch! }.to raise_error(SystemExit)
    end
  end

  describe '#update!' do
    let(:model_selector) { described_class.new }

    before do
      allow(File).to receive(:read).and_return(existing_env_content)
      allow(File).to receive(:write)
      allow(model_selector).to receive(:gets).and_return("1\n") # user selects the first model
    end

    it 'prompts the user for input, validates and saves selected model to the env file' do
      model_selector.update!
      filtered_model_data = model_data.select do |m|
        described_class::ALLOWED_OWNERS.include?(m["owned_by"]) &&
        !described_class::DISALLOED_TYPES.any? { |type| m["id"].include?(type) } &&
        m["id"].start_with?(described_class::ALLOWED_ID_PREFIX)
      end
      selected_model = filtered_model_data.first["id"]
      expect(File).to have_received(:write).with(
        env_path,
        anything
      )
      expect(File.read(env_path)).to include("#{described_class::KEY}=#{selected_model}\n")
    end
  end
end
```

In this spec, we mock the `gets` method to simulate the user's input and mock the `AiClient`'s `models_list` method to provide a pre-defined list of models without querying an external API. We use the `instance_double` for `AiClient` to ensure that it only implements the methods we expect.

Please note that RSpec will actually prevent the program from exiting the entire suite when `exit` is called by raising a `SystemExit` exception, which we can then expect in our tests. We use the `raise_error` matcher to check this.

Remember that the `File.read` and `File.write` calls in the last example assume certain behavior of the `update!` method that might be incorrect depending on the actual implementation details of the `Envs::Base` class. Adjust the implementation as needed based on how the `save_to_env!` method operates. Also, ensure that the initial conditions in the environment file and the ENV hash are set up according to the scenario you're testing.
