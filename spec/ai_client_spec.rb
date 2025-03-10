require "envs/base"
require "envs/openai_api_token"
require "envs/selected_model"
require "ai_client"

RSpec.describe AiClient do
  let(:access_token) { "test-token123" }
  let(:selected_model) { "selected_model" }
  let(:client) { instance_double(OpenAI::Client) }

  subject { described_class.new(access_token) }

  before do
    allow(Envs::OpenaiApiToken).to receive_message_chain(:new, :fetch!) { access_token }
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
          messages: instance_of(Array),
          temperature: 0.7
        )
      )
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
