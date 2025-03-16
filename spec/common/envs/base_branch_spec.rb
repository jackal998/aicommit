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
      expect(subject).to receive(:puts).with("AI_COMMIT_BASE_BRANCH saved to .env".green)

      expect(subject).to receive(:get_env_value!).and_return(base_branch)
      expect(subject.fetch!).to eq(base_branch)
    end
  end

  describe "#update!" do
    before do
      allow(File).to receive(:read).and_return(existing_env_content)
      allow(File).to receive(:write)
      allow(subject).to receive(:gets).and_return(base_branch)
      allow(subject).to receive(:validate_branch_name!).with(base_branch).and_return(base_branch)
    end

    it "prompts the user for input, validates and saves token to the env file" do
      expect(subject).to receive(:puts).with("Please enter your base branch name (or 'q' to quit):")
      expect(subject).to receive(:puts).with("AI_COMMIT_BASE_BRANCH saved to .env".green)
      subject.update!
      expect(File).to have_received(:write).with(
        env_path,
        /\A#{described_class::KEY}=#{base_branch}\n\Z/
      )
    end

    context "with provided value" do
      it "validates and saves the provided branch name" do
        expect(subject).to receive(:validate_branch_name!).with(base_branch).and_return(base_branch)
        expect(subject).to receive(:save_to_env!).with(described_class::KEY, base_branch)
        subject.update!(base_branch)
      end

      it "returns nil if validation fails" do
        expect(subject).to receive(:validate_branch_name!).with(base_branch).and_return(nil)
        expect(subject).not_to receive(:save_to_env!)
        expect(subject.update!(base_branch)).to be_nil
      end
    end
  end

  describe "#get_env_value!" do
    it "calls get_user_input!" do
      expect(subject).to receive(:get_user_input!).and_return(base_branch)
      expect(subject.send(:get_env_value!)).to eq(base_branch)
    end
  end

  describe "#get_user_input_display_messages" do
    it "returns the correct message" do
      expect(subject.send(:get_user_input_display_messages)).to eq(
        ["Please enter your base branch name (or 'q' to quit):"]
      )
    end
  end

  describe "#validate_user_input!" do
    it "delegates to validate_branch_name!" do
      expect(subject).to receive(:validate_branch_name!).with(base_branch).and_return(base_branch)
      expect(subject.send(:validate_user_input!, base_branch)).to eq(base_branch)
    end
  end

  describe "#validate_branch_name!" do
    let(:git_client) { instance_double(Common::GitClient) }

    before do
      allow(Common::GitClient).to receive(:new).and_return(git_client)
    end

    it "uses default branch name when input is empty" do
      allow(git_client).to receive(:branch_exists?).with(described_class::DEFAULT_BRANCH).and_return(true)
      expect(subject.send(:validate_branch_name!, "")).to eq(described_class::DEFAULT_BRANCH)
      expect(subject.send(:validate_branch_name!, nil)).to eq(described_class::DEFAULT_BRANCH)
      expect(subject.send(:validate_branch_name!, "  ")).to eq(described_class::DEFAULT_BRANCH)
    end

    it "returns the branch name if it exists" do
      allow(git_client).to receive(:branch_exists?).with(base_branch).and_return(true)
      expect(subject.send(:validate_branch_name!, base_branch)).to eq(base_branch)
    end

    it "returns nil if branch doesn't exist" do
      allow(git_client).to receive(:branch_exists?).with(base_branch).and_return(false)
      expect(subject).to receive(:puts).with(/Error: Branch '#{base_branch}' does not exist/).once
      expect(subject).to receive(:puts).with(/Please enter a valid branch name/).once
      expect(subject.send(:validate_branch_name!, base_branch)).to be_nil
    end
  end
end
