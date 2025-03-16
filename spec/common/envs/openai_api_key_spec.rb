require "common/envs/base"
require "common/envs/openai_api_key"
require "common/ai_client"

RSpec.describe Common::Envs::OpenaiApiKey do
  let(:api_token) { "sample_token" }
  let(:ai_client) { instance_double("Common::AiClient") }
  let(:env_path) { described_class::ENV_PATH }
  let(:existing_env_content) { "#{described_class::KEY}=old_token" }

  before do
    allow(File).to receive(:expand_path).and_return("/fakepath")
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
  end

  describe "#fetch" do
    it "returns the existing value from ENV without prompting" do
      stub_const("ENV", described_class::KEY => api_token)

      expect(subject.fetch).to eq(api_token)
    end

    context "when the value does not exist" do
      it "returns nil" do
        stub_const("ENV", {})

        expect(subject.fetch).to be_nil
      end
    end
  end

  describe "#fetch!" do
    before do
      allow(File).to receive(:write)
    end

    it "returns the existing value without prompting" do
      stub_const("ENV", described_class::KEY => api_token)

      expect(subject.fetch!).to eq(api_token)
    end

    it "prompts the user when the value is not set" do
      stub_const("ENV", {})
      expect(subject).to receive(:puts).with("AI_COMMIT_OPENAI_API_KEY saved to .env".green)

      expect(subject).to receive(:get_env_value!).and_return(api_token)
      expect(subject.fetch!).to eq(api_token)
    end
  end

  describe "#update!" do
    before do
      allow(File).to receive(:read).and_return(existing_env_content)
      allow(File).to receive(:write)
      allow(subject).to receive(:gets).and_return(api_token)
      allow(Common::AiClient).to receive(:new).with(api_token).and_return(ai_client)
      allow(ai_client).to receive(:verify_api_token!).and_return(true)
    end

    it "prompts the user for input, validates and saves token to the env file" do
      expect(subject).to receive(:puts).with("Please enter your OpenAI API token (or 'q' to quit):")
      expect(subject).to receive(:puts).with("AI_COMMIT_OPENAI_API_KEY saved to .env".green)
      subject.update!
      expect(File).to have_received(:write).with(
        env_path,
        /\A#{described_class::KEY}=#{api_token}\n\Z/
      )
    end
  end

  describe "#update! with provided value" do
    before do
      allow(File).to receive(:read).and_return(existing_env_content)
      allow(File).to receive(:write)
      allow(Common::AiClient).to receive(:new).with(api_token).and_return(ai_client)
      allow(ai_client).to receive(:verify_api_token!).and_return(true)
    end

    it "validates and saves the provided token" do
      expect(subject).to receive(:validate_token!).with(api_token).and_call_original
      expect(subject).to receive(:save_to_env!).with(described_class::KEY, api_token)
      subject.update!(api_token)
    end

    it "returns nil if validation fails" do
      allow(ai_client).to receive(:verify_api_token!).and_return(false)
      expect(subject).to receive(:puts).with(/The API key could not be verified/).once
      expect(subject).not_to receive(:save_to_env!)
      expect(subject.update!(api_token)).to be_nil
    end
  end

  describe "#get_env_value!" do
    it "calls get_user_input!" do
      expect(subject).to receive(:get_user_input!).and_return(api_token)
      expect(subject.send(:get_env_value!)).to eq(api_token)
    end
  end

  describe "#get_user_input_display_messages" do
    it "returns the expected message" do
      expect(subject.send(:get_user_input_display_messages)).to eq(
        ["Please enter your OpenAI API token (or 'q' to quit):"]
      )
    end
  end

  describe "#validate_user_input!" do
    it "delegates to validate_token!" do
      expect(subject).to receive(:validate_token!).with(api_token).and_return(api_token)
      expect(subject.send(:validate_user_input!, api_token)).to eq(api_token)
    end
  end

  describe "#validate_token!" do
    before do
      allow(Common::AiClient).to receive(:new).with(api_token).and_return(ai_client)
    end

    it "returns the token if verified successfully" do
      allow(ai_client).to receive(:verify_api_token!).and_return(true)
      expect(subject.send(:validate_token!, api_token)).to eq(api_token)
    end

    it "returns nil if verification fails" do
      allow(ai_client).to receive(:verify_api_token!).and_return(false)
      expect(subject).to receive(:puts).with(/The API key could not be verified/).once
      expect(subject.send(:validate_token!, api_token)).to be_nil
    end
  end
end
