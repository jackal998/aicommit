require "envs/base"
require "envs/openai_api_token"
require "envs/selected_model"
require "ai_client"

RSpec.describe AiClient do
  let(:access_token) { "test-token123" }
  let(:selected_model) { "selected_model" }
  let(:client) { instance_double(OpenAI::Client) }
  let(:models_response) { { "data" => ["list", "of", "models"] } }

  subject { described_class.new(access_token) }

  before do
    allow(Envs::OpenaiApiToken).to receive_message_chain(:new, :fetch!) { access_token }
    allow(Envs::SelectedModel).to receive_message_chain(:new, :fetch!) { selected_model }
    allow(OpenAI::Client).to receive(:new).with(access_token: access_token) { client }
  end

  describe "#chat" do
    let(:diff) { "Some Git diff" }
    let(:api_response) { { "choices" => [{ "message" => { "content" => "Test message" } }] } }
    let(:error_response) { { "error" => { "message" => "There was an error" } } }

    before do
      allow(client).to receive(:chat).and_return(api_response)
      allow(subject).to receive(:set_messages).with(diff).and_return([{}]) # simplifying for test
    end

    it "calls the chat endpoint with the provided diff" do
      expect(client).to receive(:chat).with(hash_including(parameters: hash_including(messages: [{}])))
      subject.chat(diff)
    end

    it "returns the chat message content" do
      expect(subject.chat(diff)).to eq("Test message")
    end

    context "when API returns an error" do
      before do
        allow(client).to receive(:chat).and_return(error_response)
      end

      it "displays the error message and exits" do
        expect { subject.chat(diff) }.to raise_error(SystemExit)
                                         .and output(/There was an error/).to_stdout
      end
    end
  end

  describe "#models_list" do
    it "calls the list endpoint" do
      expect(client).to receive_message_chain(:models, :list).and_return(models_response)
      subject.models_list
    end
  end

  describe "#verify_api_token!" do
    it "calls #models_list" do
      expect(subject).to receive(:models_list).and_return(models_response)
      subject.verify_api_token!
    end
  end
end
