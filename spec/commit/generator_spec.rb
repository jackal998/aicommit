require "commit/generator"
require "common/git_client"
require "common/ai_client"

RSpec.describe Commit::Generator do
  let(:git_client) { instance_double("Common::GitClient") }
  let(:ai_client) { instance_double("Common::AiClient") }
  let(:diff) { "sample diff content" }
  let(:commit_message) do
    {
      "subject" => "feat: Implement new feature",
      "description" => "This commit adds a new feature X that improves Y"
    }
  end

  subject { described_class.new }

  before do
    allow(Common::GitClient).to receive(:new).and_return(git_client)
    allow(Common::AiClient).to receive(:new).and_return(ai_client)
    allow(git_client).to receive(:staged_changes).and_return(diff)
    allow(ai_client).to receive(:get_commit_message).with(diff).and_return(commit_message)
  end

  describe "#initialize" do
    it "creates a new GitClient and AiClient instance" do
      expect(Common::GitClient).to receive(:new).and_return(git_client)
      expect(Common::AiClient).to receive(:new).and_return(ai_client)
      subject
    end
  end

  describe ".run" do
    it "creates a new instance and calls run" do
      generator_instance = instance_double(described_class)
      expect(described_class).to receive(:new).and_return(generator_instance)
      expect(generator_instance).to receive(:run)
      described_class.run
    end
  end

  describe "#run" do
    context "when the user accepts the commit message (Y)" do
      it "commits the changes with the generated message" do
        allow(subject).to receive(:gets).and_return("Y\n")
        expect(git_client).to receive(:commit_all).with(commit_message)
        expect { subject.run }.to output(/All changes have been successfully committed/).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when the user wants to regenerate the message (R)" do
      let(:regenerated_commit_message) do
        {
          "subject" => "fix: Update feature implementation",
          "description" => "This commit fixes an issue with feature X"
        }
      end

      it "regenerates the commit message and then commits" do
        allow(subject).to receive(:gets).and_return("R\n", "Y\n")
        expect(ai_client).to receive(:get_commit_message).with(diff).twice.and_return(
          commit_message, regenerated_commit_message
        )
        expect(git_client).to receive(:commit_all).with(regenerated_commit_message)
        expect { subject.run }.to output(/Regenerating/).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when the user wants to enter a new message (N)" do
      it "allows the user to enter a custom message" do
        allow(subject).to receive(:gets).and_return("N\n", "custom commit message\n", "Y\n")
        expect(git_client).to receive(:commit_all).with("custom commit message")
        expect { subject.run }.to output(/Please enter your new commit_message/).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when the user wants to quit (Q)" do
      it "exits without committing" do
        allow(subject).to receive(:gets).and_return("Q\n")
        expect(git_client).not_to receive(:commit_all)
        expect { subject.run }.to output(/Quit without committing/).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when the user enters an invalid command" do
      it "shows an error message and prompts again" do
        allow(subject).to receive(:gets).and_return("invalid\n", "Y\n")
        expect(git_client).to receive(:commit_all).with(commit_message)
        expect { subject.run }.to output(/Invalid command/).to_stdout.and(raise_error(SystemExit))
      end
    end
  end
end
