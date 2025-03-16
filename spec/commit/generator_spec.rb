require "commit/generator"
require "common/git_client"
require "common/ai_client"
require "openai"
require "aicommit"

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
    # Set up doubles before initializing the subject
    allow(Common::GitClient).to receive(:new).and_return(git_client)
    allow(Common::AiClient).to receive(:new).and_return(ai_client)

    # Default behavior for staged changes and commit message
    allow(git_client).to receive(:staged_changes).and_return(diff)
    allow(ai_client).to receive(:get_commit_message).with(diff).and_return(commit_message)
  end

  describe "#initialize" do
    it "creates a new GitClient and AiClient instance" do
      # Create a fresh instance to test initialization
      generator = described_class.new
      expect(generator.send(:git_client)).to eq(git_client)
      expect(generator.send(:ai_client)).to eq(ai_client)
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
    def stub_show_user_options(commit_message)
      expect($stdout).to receive(:puts).with("Do you want to use this commit message? (Y/R/Q)".green)
      expect($stdout).to receive(:puts).with("Y = Yes, commit with this message".blue)
      expect($stdout).to receive(:puts).with("R = Regenerate message".blue)
      expect($stdout).to receive(:puts).with("Q = Quit without committing".blue)
      expect($stdout).to receive(:puts).with("Commit subject: ".bold + commit_message["subject"].to_s)
      expect($stdout).to receive(:puts).with("Description: ".bold + commit_message["description"].to_s)
    end

    before do
      allow($stdout).to receive(:puts).with("")
      allow(subject).to receive(:exit) { |code| raise SystemExit.new(code) }
    end

    context "when there are no staged changes" do
      before do
        allow(git_client).to receive(:staged_changes).and_return("   ")
      end

      it "displays an error message and exits" do
        expect($stdout).to receive(:puts).with(/No staged changes found/).once
        expect { subject.run }.to raise_error(SystemExit)
      end
    end

    context "when there are staged changes" do
      context "when the user accepts the commit message (Y)" do
        let(:user_input) { ["Y\n", "y\n"].sample }

        before do
          allow(subject).to receive(:gets).and_return(user_input)
        end

        it "commits the changes with the generated message" do
          expect(git_client).to receive(:commit_all).with(commit_message)
          stub_show_user_options(commit_message)

          expect($stdout).to receive(:puts).with(/All changes have been successfully committed/).once
          expect { subject.run }.to raise_error(SystemExit)
        end
      end

      context "when the user wants to regenerate the message (R)" do
        let(:user_input) { ["R\n", "r\n"].sample }
        let(:regenerated_commit_message) do
          {
            "subject" => "fix: Update feature implementation",
            "description" => "This commit fixes an issue with feature X"
          }
        end

        before do
          allow(subject).to receive(:gets).and_return(user_input, "Y\n")
        end

        it "regenerates the commit message and then commits" do
          expect(ai_client).to receive(:get_commit_message).with(diff).twice.and_return(
            commit_message, regenerated_commit_message
          )
          stub_show_user_options(commit_message)

          expect($stdout).to receive(:puts).with(/Regenerating/).once
          stub_show_user_options(regenerated_commit_message)

          expect(git_client).to receive(:commit_all).with(regenerated_commit_message)
          expect($stdout).to receive(:puts).with(/All changes have been successfully committed/).once
          expect { subject.run }.to raise_error(SystemExit)
        end
      end

      context "when the user types an invalid option then accepts the message" do
        before do
          allow(subject).to receive(:gets).and_return("N\n", "Y\n")
        end

        it "shows an error then allows the user to commit" do
          stub_show_user_options(commit_message)
          expect($stdout).to receive(:puts).with(/Invalid command/).once
          stub_show_user_options(commit_message)
          expect(git_client).to receive(:commit_all).with(commit_message)
          expect($stdout).to receive(:puts).with(/All changes have been successfully committed/).once
          expect { subject.run }.to raise_error(SystemExit)
        end
      end

      context "when the user wants to quit (Q)" do
        let(:user_input) { ["Q\n", "q\n"].sample }

        before do
          allow(subject).to receive(:gets).and_return(user_input)
        end

        it "exits without committing" do
          stub_show_user_options(commit_message)
          expect(git_client).not_to receive(:commit_all)
          expect($stdout).to receive(:puts).with(/Quit without committing/).once
          expect { subject.run }.to raise_error(SystemExit)
        end
      end
    end

    context "when an OpenAI error occurs" do
      before do
        allow(ai_client).to receive(:get_commit_message).and_raise(OpenAI::Error.new("API error"))
      end

      it "handles the error using Aicommit.handle_error" do
        expect(Aicommit).to receive(:handle_error).with(an_instance_of(OpenAI::Error)).and_call_original
        expect($stdout).to receive(:puts).with(/Error: API error/).once
        expect { subject.run }.to raise_error(SystemExit)
      end
    end

    context "when a general error occurs" do
      before do
        allow(ai_client).to receive(:get_commit_message).and_raise(StandardError.new("General error"))
      end

      it "outputs the error message and exits" do
        expect(Aicommit).to receive(:handle_error).with(an_instance_of(StandardError)).and_call_original
        expect($stdout).to receive(:puts).with(/Error: General error/).once
        expect { subject.run }.to raise_error(SystemExit)
      end
    end
  end
end
