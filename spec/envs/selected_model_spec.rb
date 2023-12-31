require "envs/base"
require "envs/selected_model"
require "ai_client"

RSpec.describe Envs::SelectedModel do
  let(:model_data) do
    [
      { "id" => "gpt-3.5-turbo", "owned_by" => "openai" },
      { "id" => "gpt-3-abc", "owned_by" => "openai" },
      { "id" => "vision-model", "owned_by" => "system" },
      { "id" => "gpt-2.5-instruct", "owned_by" => "openai" }
    ]
  end

  let(:saved_selected_model) { "selected_model" }
  let(:ai_client) { instance_double("AiClient") }
  let(:env_path) { described_class::ENV_PATH }
  let(:existing_env_content) { "#{described_class::KEY}=old_model" }

  before do
    allow(File).to receive(:expand_path).and_return("/fakepath")
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
    allow(AiClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:models_list).and_return({ "data" => model_data })
  end

  describe "#fetch" do
    it "returns the existing value from ENV without prompting" do
      stub_const("ENV", described_class::KEY => saved_selected_model)

      expect(subject.fetch).to eq(saved_selected_model)
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
      allow(subject).to receive(:puts).with("Please select a model: (1-2)")
      allow(subject).to receive(:puts).with("1. gpt-3.5-turbo")
      allow(subject).to receive(:puts).with("2. gpt-3-abc")
      allow(File).to receive(:write)
    end

    it "returns the existing value without prompting" do
      stub_const("ENV", described_class::KEY => saved_selected_model)

      expect(subject.fetch!).to eq(saved_selected_model)
    end

    it "prompts the user and returns the selected model" do
      stub_const("ENV", {})
      expect(subject).to receive(:puts).with("saved to .env".green)

      allow(subject).to receive(:gets).and_return("2\n") # user selects the second model
      expect(subject.fetch!).to eq(model_data[1]["id"])
    end

    it "exits the program if an invalid selection is made" do
      stub_const("ENV", {})
      expect(subject).to receive(:puts).with("Invalid selection, exiting program.")

      allow(subject).to receive(:gets).and_return("10\n") # invalid selection
      expect { subject.fetch! }.to raise_error(SystemExit)
    end
  end

  describe "#update!" do
    before do
      allow(File).to receive(:read).and_return(existing_env_content)
      allow(File).to receive(:write)
      allow(subject).to receive(:gets).and_return("1\n") # user selects the first model
    end

    it "prompts the user for input, validates and saves selected model to the env file" do
      expect(subject).to receive(:puts).with("Please select a model: (1-2)")
      expect(subject).to receive(:puts).with("1. gpt-3.5-turbo")
      expect(subject).to receive(:puts).with("2. gpt-3-abc")
      expect(subject).to receive(:puts).with("saved to .env".green)

      subject.update!
      filtered_model_data = model_data.select do |m|
        described_class::ALLOWED_OWNERS.include?(m["owned_by"]) &&
        !described_class::DISALLOED_TYPES.any? { |type| m["id"].include?(type) } &&
        m["id"].start_with?(described_class::ALLOWED_ID_PREFIX)
      end
      selected_model = filtered_model_data.first["id"]
      expect(File).to have_received(:write).with(
        env_path,
        include("#{described_class::KEY}=#{selected_model}\n")
      )
    end
  end
end
