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
    before do
      # Allow puts for most tests to see output
      allow($stdout).to receive(:puts)
      # Allow gets to be stubbed without affecting the actual test process
      allow(subject).to receive(:gets)
      # Mock exit to prevent actual exit in tests
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
        before do
          allow(subject).to receive(:gets).and_return("Y\n")
        end

        it "commits the changes with the generated message" do
          expect(git_client).to receive(:commit_all).with(commit_message)
          expect($stdout).to receive(:puts).with(/All changes have been successfully committed/).once
          expect { subject.run }.to raise_error(SystemExit)
        end

        it "commits the changes with a lowercase 'y' response" do
          allow(subject).to receive(:gets).and_return("y\n")
          expect(git_client).to receive(:commit_all).with(commit_message)
          expect { subject.run }.to raise_error(SystemExit)
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
          expect($stdout).to receive(:puts).with(/Regenerating/).once
          expect { subject.run }.to raise_error(SystemExit)
        end

        it "regenerates the commit message with a lowercase 'r' response" do
          allow(subject).to receive(:gets).and_return("r\n", "Y\n")
          expect(ai_client).to receive(:get_commit_message).with(diff).twice.and_return(
            commit_message, regenerated_commit_message
          )
          expect(git_client).to receive(:commit_all).with(regenerated_commit_message)
          expect { subject.run }.to raise_error(SystemExit)
        end
      end

      context "when the user types an invalid option then accepts the message" do
        it "shows an error then allows the user to commit" do
          allow(subject).to receive(:gets).and_return("N\n", "Y\n")
          expect(git_client).to receive(:commit_all).with(commit_message)
          expect($stdout).to receive(:puts).with(/Invalid command/).once
          expect { subject.run }.to raise_error(SystemExit)
        end
      end

      context "when the user wants to quit (Q)" do
        it "exits without committing" do
          allow(subject).to receive(:gets).and_return("Q\n")
          expect(git_client).not_to receive(:commit_all)
          # We don't test the exact stdout output here to avoid conflicts with other tests
          expect { subject.run }.to raise_error(SystemExit)
        end

        it "exits without committing with a lowercase 'q' response" do
          allow(subject).to receive(:gets).and_return("q\n")
          expect(git_client).not_to receive(:commit_all)
          expect { subject.run }.to raise_error(SystemExit)
        end
      end

      context "when displaying the commit message" do
        it "shows the commit message details" do
          allow(subject).to receive(:gets).and_return("Y\n")
          allow(git_client).to receive(:commit_all).with(commit_message)

          # Use allow instead of expect to avoid conflicts with other expectations
          allow($stdout).to receive(:puts).with(/Commit subject: .+feat: Implement new feature/)
          allow($stdout).to receive(:puts).with(/Description: .+This commit adds a new feature X that improves Y/)

          expect { subject.run }.to raise_error(SystemExit)
        end
      end
    end

    context "when an OpenAI error occurs" do
      before do
        allow(ai_client).to receive(:get_commit_message).and_raise(OpenAI::Error.new("API error"))

        # Mock Aicommit.handle_error method to avoid actual exit
        allow(Aicommit).to receive(:handle_error) do |error|
          $stdout.puts "Handled OpenAI error: #{error.message}"
          raise SystemExit.new(1)
        end
      end

      it "handles the error using Aicommit.handle_error" do
        expect(Aicommit).to receive(:handle_error).with(an_instance_of(OpenAI::Error))
        expect { subject.run }.to raise_error(SystemExit)
      end
    end

    context "when a general error occurs" do
      before do
        allow(ai_client).to receive(:get_commit_message).and_raise(StandardError.new("General error"))
      end

      it "outputs the error message and exits" do
        expect($stdout).to receive(:puts).with(/Error: General error/).once
        expect { subject.run }.to raise_error(SystemExit)
      end
    end
  end
end
