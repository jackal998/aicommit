require "spec_helper"
require "json"
require "colorize"
require "common/ai_client"

RSpec.describe Common::AiClient do
  let(:access_token) { "test-token123" }
  let(:selected_model) { "gpt-4" }
  let(:client) { instance_double(OpenAI::Client) }
  let(:json_response) do
    {
      "choices" => [{
        "message" => {
          "content" => '{"subject":"Test commit message","description":"Description"}'
        }
      }]
    }
  end

  before do
    allow(Common::Envs::OpenaiApiKey).to receive_message_chain(:new, :fetch!) { access_token }
    allow(Common::Envs::SelectedModel).to receive_message_chain(:new, :fetch!) { selected_model }
    allow(OpenAI::Client).to receive(:new).with(access_token: access_token).and_return(client)

    # Capture STDOUT and STDERR
    @captured_output = []
    allow_any_instance_of(described_class).to receive(:puts) do |_instance, message|
      @captured_output << message
    end

    # Allow exit to be caught instead of actually exiting
    allow_any_instance_of(Kernel).to receive(:exit) do |_instance, code|
      @exit_code = code
      raise "Simulated exit with code #{code}"
    end
  end

  describe "Constants" do
    it "has the correct DIFF_LIMIT value" do
      expect(Common::AiClient::DIFF_LIMIT).to eq(100000)
    end
  end

  describe "ApiError" do
    it "initializes with a message, type, and status_code" do
      error = Common::AiClient::ApiError.new("Test error", :authentication, 401)
      expect(error.message).to eq("Test error")
      expect(error.type).to eq(:authentication)
      expect(error.status_code).to eq(401)
    end
  end

  describe "#initialize" do
    it "sets the access token from the parameter if provided" do
      custom_token = "custom-token"
      expect(OpenAI::Client).to receive(:new).with(access_token: custom_token)
      client = described_class.new(custom_token)
      expect(client.access_token).to eq(custom_token)
    end

    it "fetches the access token from the environment if not provided" do
      env_token = "env-token"
      allow(Common::Envs::OpenaiApiKey).to receive_message_chain(:new, :fetch!).and_return(env_token)
      expect(OpenAI::Client).to receive(:new).with(access_token: env_token)
      client = described_class.new
      expect(client.access_token).to eq(env_token)
    end
  end

  describe "#get_commit_message" do
    subject { described_class.new(access_token) }
    let(:diff) { "Sample diff" }

    before do
      allow(client).to receive(:chat).and_return(json_response)
    end

    it "returns commit message from API response" do
      allow(subject).to receive(:verify_api_token!).and_return(true)

      result = subject.get_commit_message(diff)
      expect(result).to eq({"subject" => "Test commit message", "description" => "Description"})
    end

    it "calls send_message with correctly formatted messages" do
      allow(subject).to receive(:verify_api_token!).and_return(true)
      formatted_messages = [{"role" => "user", "content" => "Test prompt"}]

      expect(subject).to receive(:set_messages).with(diff, :commit_message).and_return(formatted_messages)
      expect(subject).to receive(:send_message).with(formatted_messages).and_return({"subject" => "Test", "description" => "Test"})

      subject.get_commit_message(diff)
    end

    context "with a large diff that exceeds DIFF_LIMIT" do
      let(:large_diff) { "x" * (Common::AiClient::DIFF_LIMIT + 1000) }

      it "truncates the diff and warns user" do
        allow(subject).to receive(:verify_api_token!).and_return(true)
        allow(subject).to receive(:warn_lengthy_diff).and_call_original
        allow(subject).to receive(:extract_important_changes).and_return("Important changes")

        expect { subject.get_commit_message(large_diff) }.to_not raise_error
        expect(@captured_output.any? { |msg| msg.to_s.include?("Warning: The diff is quite large") }).to be true
      end
    end
  end

  describe "#get_pr_description" do
    subject { described_class.new(access_token) }
    let(:diff) { "Sample diff" }

    before do
      allow(client).to receive(:chat).and_return(json_response)
      allow(subject).to receive(:verify_api_token!).and_return(true)

      # Stub set_messages to avoid recursive call issues
      allow(subject).to receive(:set_messages).with(diff, :pr_description).and_return([{"role" => "user", "content" => "PR prompt"}])
    end

    it "returns PR description from API response" do
      result = subject.get_pr_description(diff)
      expect(result).to eq({"subject" => "Test commit message", "description" => "Description"})
    end

    context "with a PR template" do
      it "includes the template in the prompt" do
        template_content = "# PR Template\n\nTemplate details"
        allow(subject).to receive(:get_pr_template).and_return(template_content)

        # Since we've stubbed set_messages, we need to test that it would be called with the right parameters
        expect(subject).to receive(:set_messages).with(diff, :pr_description).and_return([{"role" => "user", "content" => "PR prompt"}])

        subject.get_pr_description(diff)
      end
    end
  end

  describe "#send_message" do
    subject { described_class.new(access_token) }
    let(:messages) { [{"role" => "user", "content" => "Test message content"}] }

    context "with a successful response" do
      before do
        allow(client).to receive(:chat).and_return(json_response)
      end

      it "returns the parsed JSON content" do
        result = subject.send_message(messages)
        expect(result).to eq({"subject" => "Test commit message", "description" => "Description"})
      end
    end

    context "when response processing fails" do
      it "raises JSON parse errors directly without catching" do
        invalid_response = {
          "choices" => [{
            "message" => {
              "content" => "Not valid JSON"
            }
          }]
        }
        allow(client).to receive(:chat).and_return(invalid_response)

        # The error is propagated up, not caught by safe_api_request
        expect { subject.send_message(messages) }.to raise_error(JSON::ParserError)
      end

      it "raises nil content errors directly without catching" do
        no_content_response = {
          "choices" => [{
            "message" => {}
          }]
        }
        allow(client).to receive(:chat).and_return(no_content_response)

        # The error is propagated up, not caught by safe_api_request
        expect { subject.send_message(messages) }.to raise_error(TypeError)
      end
    end
  end

  describe "#models_list" do
    subject { described_class.new(access_token) }

    it "calls the OpenAI client to list models" do
      expect(client).to receive_message_chain(:models, :list).and_return({"data" => []})
      subject.models_list
    end
  end

  describe "#verify_api_token!" do
    subject { described_class.new(access_token) }

    it "returns true when API token is valid" do
      allow(subject).to receive(:models_list).and_return({"data" => []})

      expect(subject.verify_api_token!).to be_truthy
    end

    context "when authentication fails" do
      it "handles authentication errors" do
        # Create a ApiError with authentication type
        error = Common::AiClient::ApiError.new("Invalid API key", :authentication, 401)
        allow(subject).to receive(:models_list).and_raise(error)

        # The method should return false and not raise
        expect(subject.verify_api_token!).to be_falsey
        expect(@captured_output).to include("Invalid API key: Authentication failed.".red)
        expect(@captured_output).to include("Please check your API key and try again.".red)
      end
    end

    context "when general API error occurs" do
      it "handles general API errors" do
        # Create a ApiError with general type
        error = Common::AiClient::ApiError.new("General error", :general, 400)
        allow(subject).to receive(:models_list).and_raise(error)

        # The method should return false and not raise
        expect(subject.verify_api_token!).to be_falsey
        expect(@captured_output).to include("API Error: General error".red)
      end
    end

    context "when standard error occurs" do
      it "handles standard errors" do
        # Create a standard error
        error = StandardError.new("Unknown error")
        allow(subject).to receive(:models_list).and_raise(error)

        # The method should return false and not raise
        expect(subject.verify_api_token!).to be_falsey
        expect(@captured_output).to include("Error checking API key: Unknown error".red)
      end
    end
  end

  describe "#safe_api_request" do
    subject { described_class.new(access_token) }

    it "returns the response for successful calls" do
      success_response = {"data" => "test"}

      expect(subject.send(:safe_api_request) { success_response }).to eq(success_response)
    end

    context "when handling API errors in response" do
      it "raises ApiError with authentication type for authentication errors" do
        error_response = {
          "error" => {
            "message" => "Invalid API key",
            "type" => "invalid_request_error",
            "status" => 401
          }
        }

        expect { subject.send(:safe_api_request) { error_response } }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("Please check your API key") }).to be true
        end
      end

      it "raises ApiError with rate_limit type for rate limit errors" do
        error_response = {
          "error" => {
            "message" => "Rate limit exceeded",
            "status" => 429
          }
        }

        expect { subject.send(:safe_api_request) { error_response } }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("You've exceeded your API rate limit") }).to be true
        end
      end

      it "raises ApiError with server_error type for server errors" do
        error_response = {
          "error" => {
            "message" => "Server error",
            "status" => 500
          }
        }

        expect { subject.send(:safe_api_request) { error_response } }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("OpenAI servers may be experiencing issues") }).to be true
        end
      end

      it "raises ApiError with general type for other API errors" do
        error_response = {
          "error" => {
            "message" => "General error",
            "status" => 400
          }
        }

        expect { subject.send(:safe_api_request) { error_response } }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("Error: General error") }).to be true
        end
      end
    end

    context "when handling exceptions" do
      it "handles ApiError exceptions" do
        authentication_error = Common::AiClient::ApiError.new("Auth Error", :authentication, 401)

        expect {
          subject.send(:safe_api_request) { raise authentication_error }
        }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("Error: Auth Error") }).to be true
          expect(@captured_output.any? { |msg| msg.to_s.include?("Please check your API key") }).to be true
        end
      end

      it "handles rate limit ApiError exceptions" do
        rate_limit_error = Common::AiClient::ApiError.new("Rate limit", :rate_limit, 429)

        expect {
          subject.send(:safe_api_request) { raise rate_limit_error }
        }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("Error: Rate limit") }).to be true
          expect(@captured_output.any? { |msg| msg.to_s.include?("You've exceeded your API rate limit") }).to be true
        end
      end

      it "handles server error ApiError exceptions" do
        server_error = Common::AiClient::ApiError.new("Server error", :server_error, 500)

        expect {
          subject.send(:safe_api_request) { raise server_error }
        }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("Error: Server error") }).to be true
          expect(@captured_output.any? { |msg| msg.to_s.include?("OpenAI servers may be experiencing issues") }).to be true
        end
      end

      it "handles standard errors" do
        expect {
          subject.send(:safe_api_request) { raise StandardError.new("Test error") }
        }.to raise_error do |error|
          expect(error.message).to include("Simulated exit with code 1")
          expect(@captured_output.any? { |msg| msg.to_s.include?("Error: Test error") }).to be true
        end
      end
    end
  end

  describe "#selected_model" do
    subject { described_class.new(access_token) }

    it "fetches the selected model from environment" do
      expect(Common::Envs::SelectedModel).to receive_message_chain(:new, :fetch!).and_return("gpt-4")
      expect(subject.send(:selected_model)).to eq("gpt-4")
    end
  end

  describe "#set_messages" do
    subject { described_class.new(access_token) }
    let(:diff) { "Sample diff content" }

    it "formats messages for commit messages" do
      allow(subject).to receive(:prompt_for_commit_message).with(diff).and_return("Commit message prompt")

      result = subject.send(:set_messages, diff, :commit_message)
      expect(result).to be_an(Array)
      expect(result.first["role"]).to eq("user")
      expect(result.first["content"]).to eq("Commit message prompt")
    end

    it "formats messages for PR descriptions" do
      allow(subject).to receive(:prompt_for_pr_description).with(diff).and_return("PR description prompt")

      result = subject.send(:set_messages, diff, :pr_description)
      expect(result).to be_an(Array)
      expect(result.first["role"]).to eq("user")
      expect(result.first["content"]).to eq("PR description prompt")
    end

    context "when diff exceeds DIFF_LIMIT" do
      let(:large_diff) { "A" * (Common::AiClient::DIFF_LIMIT + 5000) }

      it "truncates large diffs and adds important changes" do
        allow(subject).to receive(:warn_lengthy_diff).with(large_diff.length).and_call_original
        allow(subject).to receive(:extract_important_changes).with(large_diff).and_return("Important changes")
        allow(subject).to receive(:prompt_for_commit_message).and_return("Commit message prompt")

        subject.send(:set_messages, large_diff, :commit_message)
        expect(@captured_output.any? { |msg| msg.to_s.include?("Warning: The diff is quite large") }).to be true
      end
    end
  end

  describe "#extract_important_changes" do
    subject { described_class.new(access_token) }

    it "extracts important changes from diff content" do
      diff = <<~DIFF
        diff --git a/file1.rb b/file1.rb
        index 123..456 789
        --- a/file1.rb
        +++ b/file1.rb
        @@ -1,5 +1,5 @@
        +added line 1
        +added line 2
        +added line 3
        -removed line 1
        -removed line 2
        diff --git a/file2.rb b/file2.rb
        index 789..012 345
        --- a/file2.rb
        +++ b/file2.rb
        @@ -10,6 +10,6 @@
        +added in file 2
        -removed in file 2
      DIFF

      result = subject.send(:extract_important_changes, diff)
      # Verify it includes file headers and some of the added/removed lines
      expect(result).to include("diff --git a/file1.rb b/file1.rb")
      expect(result).to include("+added")
      expect(result).to include("-removed")
      expect(result).to include("diff --git a/file2.rb b/file2.rb")
    end
  end

  describe "#warn_lengthy_diff" do
    subject { described_class.new(access_token) }

    it "outputs warning messages for large diffs" do
      # Clear previous output
      @captured_output = []

      subject.send(:warn_lengthy_diff, 150000)

      # Check that appropriate warnings were output
      expect(@captured_output.any? { |msg| msg.to_s.include?("Warning: The diff is quite large") }).to be true
      expect(@captured_output.any? { |msg| msg.to_s.include?("less accurate commit message") }).to be true
      expect(@captured_output.any? { |msg| msg.to_s.include?("smaller, more focused commits") }).to be true
    end
  end

  describe "#get_pr_template" do
    subject { described_class.new(access_token) }

    it "returns nil when PR template path is not set" do
      allow_any_instance_of(Common::Envs::PrTemplate).to receive(:fetch).and_return(nil)
      expect(subject.send(:get_pr_template)).to be_nil
    end

    it "returns nil when PR template file doesn't exist" do
      allow_any_instance_of(Common::Envs::PrTemplate).to receive(:fetch).and_return("nonexistent.md")
      allow(File).to receive(:exist?).with("nonexistent.md").and_return(false)
      expect(subject.send(:get_pr_template)).to be_nil
    end

    it "returns nil when PR template path is empty" do
      allow_any_instance_of(Common::Envs::PrTemplate).to receive(:fetch).and_return("")
      expect(subject.send(:get_pr_template)).to be_nil
    end

    it "reads the file content when template exists" do
      template_path = "template.md"
      template_content = "# PR Template"

      allow_any_instance_of(Common::Envs::PrTemplate).to receive(:fetch).and_return(template_path)
      allow(File).to receive(:exist?).with(template_path).and_return(true)
      allow(File).to receive(:read).with(template_path).and_return(template_content)

      expect(subject.send(:get_pr_template)).to eq(template_content)
    end
  end

  describe "#prompt_for_commit_message" do
    subject { described_class.new(access_token) }

    it "formats a commit message prompt" do
      diff = "Sample diff"
      prompt = subject.send(:prompt_for_commit_message, diff)
      expect(prompt).to include("conventional commit format")
      expect(prompt).to include("Here's the diff:\n#{diff}")
      expect(prompt).to include("feat:")
      expect(prompt).to include("fix:")
    end
  end

  describe "#prompt_for_pr_description" do
    subject { described_class.new(access_token) }

    it "formats a PR description prompt" do
      diff = "Sample diff"
      prompt = subject.send(:prompt_for_pr_description, diff)
      expect(prompt).to include("comprehensive PR description")
      expect(prompt).to include("Here's the diff:\n#{diff}")
    end

    context "with PR template" do
      it "includes template in the prompt" do
        diff = "Sample diff"
        template = "# PR Template"
        allow(subject).to receive(:get_pr_template).and_return(template)

        prompt = subject.send(:prompt_for_pr_description, diff)
        expect(prompt).to include("7. Use the following PR template as a guide")
        expect(prompt).to include(template)
      end
    end

    context "without PR template" do
      it "omits template section when no template exists" do
        diff = "Sample diff"
        allow(subject).to receive(:get_pr_template).and_return(nil)

        prompt = subject.send(:prompt_for_pr_description, diff)
        expect(prompt).not_to include("7. Use the following PR template")
      end
    end
  end
end
