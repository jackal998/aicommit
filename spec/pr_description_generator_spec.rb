require "pr_description_generator"
require "git_client"
require "ai_client"

RSpec.describe PrDescriptionGenerator do
  let(:git_client) { instance_double("GitClient") }
  let(:ai_client) { instance_double("AiClient") }
  let(:base_branch) { "develop" }
  let(:commit_sha) { "abc123def456" }
  let(:diff) { "sample diff content" }
  let(:pr_description) do
    {
      "title" => "Implement new feature",
      "description" => "## Overview\nThis PR implements a new feature.\n\n## Changes\n- Added feature X\n- Fixed bug Y"
    }
  end

  before do
    allow(GitClient).to receive(:new).and_return(git_client)
    allow(AiClient).to receive(:new).and_return(ai_client)
    allow(Envs::BaseBranch).to receive_message_chain(:new, :fetch!).and_return(base_branch)
  end

  describe "#initialize" do
    it "creates a new GitClient and AiClient instance" do
      expect(GitClient).to receive(:new).and_return(git_client)
      expect(AiClient).to receive(:new).and_return(ai_client)
      subject
    end

    context "with base_ref parameter" do
      subject { described_class.new(commit_sha) }

      it "stores the base_ref parameter" do
        expect(subject.instance_variable_get(:@base_ref)).to eq(commit_sha)
      end
    end
  end

  describe "#run" do
    before do
      allow(File).to receive(:open).and_yield(StringIO.new)
      allow(StringIO.new).to receive(:puts)
    end

    context "when no base_ref is specified in the constructor" do
      before do
        allow(git_client).to receive(:diff_from_branch_root).with(base_branch).and_return(diff)
      end

      it "uses the configured base branch" do
        expect(Envs::BaseBranch).to receive_message_chain(:new, :fetch!).and_return(base_branch)
        expect(git_client).to receive(:diff_from_branch_root).with(base_branch).and_return(diff)
        expect(ai_client).to receive(:get_pr_description).with(diff).and_return(pr_description)

        expect { subject.run }.to output(/PR description has been saved to PR_DESCRIPTION.md/).to_stdout
      end
    end

    context "when a base_ref is specified in the constructor" do
      subject { described_class.new(commit_sha) }

      before do
        allow(git_client).to receive(:diff_from_branch_root).with(commit_sha).and_return(diff)
      end

      it "uses the specified base_ref" do
        expect(Envs::BaseBranch).not_to receive(:new)
        expect(git_client).to receive(:diff_from_branch_root).with(commit_sha).and_return(diff)
        expect(ai_client).to receive(:get_pr_description).with(diff).and_return(pr_description)

        expect { subject.run }.to output(/PR description has been saved to PR_DESCRIPTION.md/).to_stdout
      end
    end
  end

  describe "#save_pr_description" do
    let(:file) { instance_double(File) }

    before do
      allow(File).to receive(:open).and_yield(file)
      allow(file).to receive(:puts)
    end

    it "writes the PR description to a markdown file" do
      expect(File).to receive(:open).with("PR_DESCRIPTION.md", "w")
      expect(file).to receive(:puts).with("# #{pr_description["title"]}")
      expect(file).to receive(:puts).with("")
      expect(file).to receive(:puts).with(pr_description["description"])

      subject.send(:save_pr_description, pr_description)
    end
  end
end
