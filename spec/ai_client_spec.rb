require "envs/base"
require "envs/openai_api_key"
require "envs/selected_model"
require "ai_client"

RSpec.describe AiClient do
  let(:access_token) { "test-token123" }
  let(:selected_model) { "selected_model" }
  let(:client) { instance_double(OpenAI::Client) }

  subject { described_class.new(access_token) }

  before do
    allow(Envs::OpenaiApiKey).to receive_message_chain(:new, :fetch!) { access_token }
    allow(Envs::SelectedModel).to receive_message_chain(:new, :fetch!) { selected_model }
    allow(OpenAI::Client).to receive(:new).with(access_token: access_token).and_return(client)
  end

  describe "#get_commit_message" do
    let(:diff) { "Some Git diff" }
    let(:json_content) { '{"subject":"Commit subject","description":"Commit description"}' }
    let(:api_response) {
      {
        "choices" => [
          {
            "message" => {
              "content" => json_content
            }
          }
        ]
      }
    }
    let(:error_response) { {"error" => {"message" => "There was an error"}} }

    before do
      allow(client).to receive(:chat).and_return(api_response)
    end

    it "calls the OpenAI API with the provided diff" do
      expect(client).to receive(:chat).with(
        parameters: hash_including(
          model: selected_model,
          response_format: {type: "json_object"},
          temperature: 0.7
        )
      )
      expect(subject).to receive(:set_messages).with(diff, :commit_message).and_call_original
      subject.get_commit_message(diff)
    end

    it "returns the parsed JSON response" do
      expect(subject.get_commit_message(diff)).to eq({"subject" => "Commit subject", "description" => "Commit description"})
    end

    context "when API returns an error" do
      before do
        allow(client).to receive(:chat).and_return(error_response)
      end

      it "displays the error message and exits" do
        expect { subject.get_commit_message(diff) }.to raise_error(SystemExit)
          .and output(/There was an error/).to_stdout
      end
    end
  end

  describe "#get_pr_description" do
    let(:diff) { "Some Git diff" }
    let(:json_content) { '{"title":"PR Title","description":"PR description with markdown"}' }
    let(:api_response) {
      {
        "choices" => [
          {
            "message" => {
              "content" => json_content
            }
          }
        ]
      }
    }
    let(:error_response) { {"error" => {"message" => "There was an error"}} }

    before do
      allow(client).to receive(:chat).and_return(api_response)
    end

    it "calls the OpenAI API with the provided diff" do
      expect(client).to receive(:chat).with(
        parameters: hash_including(
          model: selected_model,
          response_format: {type: "json_object"},
          temperature: 0.7
        )
      )
      expect(subject).to receive(:set_messages).with(diff, :pr_description).and_call_original
      subject.get_pr_description(diff)
    end

    it "returns the parsed JSON response" do
      expect(subject.get_pr_description(diff)).to eq({"title" => "PR Title", "description" => "PR description with markdown"})
    end

    context "when API returns an error" do
      before do
        allow(client).to receive(:chat).and_return(error_response)
      end

      it "displays the error message and exits" do
        expect { subject.get_pr_description(diff) }.to raise_error(SystemExit)
          .and output(/There was an error/).to_stdout
      end
    end
  end

  describe "#send_message" do
    let(:messages) { "Test message content" }
    let(:json_content) { '{"key":"value"}' }
    let(:api_response) {
      {
        "choices" => [
          {
            "message" => {
              "content" => json_content
            }
          }
        ]
      }
    }

    before do
      allow(client).to receive(:chat).and_return(api_response)
    end

    it "calls the OpenAI API with the provided messages" do
      expect(client).to receive(:chat).with(
        parameters: hash_including(
          model: selected_model,
          response_format: {type: "json_object"},
          messages: messages,
          temperature: 0.7
        )
      )
      subject.send_message(messages)
    end

    it "returns the parsed JSON response" do
      expect(subject.send_message(messages)).to eq({"key" => "value"})
    end
  end

  describe "#set_messages" do
    let(:diff) { "Some Git diff" }

    it "returns messages array for commit message" do
      result = subject.send(:set_messages, diff, :commit_message)
      expect(result).to be_an(Array)
      expect(result.first[:role]).to eq("user")
      expect(result.first[:content]).to include("Instruction:")
      expect(result.first[:content]).to include("Input:\nSome Git diff")
    end

    it "returns messages array for PR description" do
      result = subject.send(:set_messages, diff, :pr_description)
      expect(result).to be_an(Array)
      expect(result.first[:role]).to eq("user")
      expect(result.first[:content]).to include("Instruction:")
      expect(result.first[:content]).to include("Input:\nSome Git diff")
    end

    context "when diff exceeds the limit" do
      let(:long_diff) { "a" * (AiClient::DIFF_LIMIT + 1000) }

      it "trims the diff and warns the user" do
        expect(subject).to receive(:warn_lengthy_diff)
        result = subject.send(:set_messages, long_diff, :commit_message)
        expect(result.first[:content]).to include("Input:\n#{'a' * AiClient::DIFF_LIMIT}")
      end
    end
  end

  describe "#prompt_for_commit_message" do
    let(:diff) { "Some Git diff" }

    it "creates a formatted prompt with the diff content" do
      result = subject.send(:prompt_for_commit_message, diff)
      expect(result).to include("Instruction:")
      expect(result).to include("Input:\n#{diff}")
      expect(result).to include("Output:")
      expect(result).to include("Example:")
    end
  end

  describe "#prompt_for_pr_description" do
    let(:diff) { "Some Git diff" }

    it "creates a formatted prompt with the diff content" do
      result = subject.send(:prompt_for_pr_description, diff)
      expect(result).to include("Instruction:")
      expect(result).to include("Input:\n#{diff}")
      expect(result).to include("Output:")
      expect(result).to include("Example:")
    end
  end

  describe "#models_list" do
    let(:models_response) { {"data" => ["list", "of", "models"]} }

    it "calls the list endpoint" do
      expect(client).to receive_message_chain(:models, :list).and_return(models_response)
      subject.models_list
    end
  end

  describe "#verify_api_token!" do
    let(:models_response) { {"data" => ["list", "of", "models"]} }

    it "calls #models_list" do
      expect(client).to receive_message_chain(:models, :list).and_return(models_response)
      subject.verify_api_token!
    end
  end
end
