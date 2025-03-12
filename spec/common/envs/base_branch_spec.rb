require "common/envs/base"
require "common/envs/base_branch"
require "common/ai_client"

RSpec.describe Common::Envs::BaseBranch do
  let(:base_branch) { "sample_branch" }
  let(:env_path) { described_class::ENV_PATH }
  let(:existing_env_content) { "#{described_class::KEY}=old_branch" }

  before do
    allow(File).to receive(:expand_path).and_return("/fakepath")
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
  end

  describe "#fetch" do
    it "returns the existing value from ENV without prompting" do
      stub_const("ENV", described_class::KEY => base_branch)

      expect(subject.fetch).to eq(base_branch)
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
      stub_const("ENV", described_class::KEY => base_branch)

      expect(subject.fetch!).to eq(base_branch)
    end

    it "prompts the user when the value is not set" do
      stub_const("ENV", {})
      expect(subject).to receive(:puts).with("saved to .env".green)

      expect(subject).to receive(:get_env_value!).and_return(base_branch)
      expect(subject.fetch!).to eq(base_branch)
    end
  end

  describe "#update!" do
    before do
      allow(File).to receive(:read).and_return(existing_env_content)
      allow(File).to receive(:write)
      allow(subject).to receive(:gets).and_return(base_branch)
    end

    it "prompts the user for input, validates and saves token to the env file" do
      expect(subject).to receive(:puts).with("Please enter your base branch name (or 'q' to quit):")
      expect(subject).to receive(:puts).with("saved to .env".green)
      subject.update!
      expect(File).to have_received(:write).with(
        env_path,
        /\A#{described_class::KEY}=#{base_branch}\n\Z/
      )
    end
  end
end
