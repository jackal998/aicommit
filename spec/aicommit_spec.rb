require "aicommit"

describe Aicommit do
  let(:ai_client) { instance_double(AiClient) }
  let(:git_client) { instance_double(GitClient) }

  before do
    allow(AiClient).to receive(:new).and_return(ai_client)
    allow(GitClient).to receive(:new).and_return(git_client)
  end

  describe "#run" do
    let(:commit_message) { {"subject" => "Test subject", "description" => "Test description"} }

    before { allow(git_client).to receive(:staged_changes).and_return("diff") }

    it "displays commit options and processes user choice" do
      expect(ai_client).to receive(:get_commit_message).with("diff").and_return(commit_message)
      allow(subject).to receive(:gets).and_return("Y\n")

      expect(git_client).to receive(:commit_all).with(commit_message)
      expect { subject.run }.to output(/Do you want to keep this commit_message?/).to_stdout.and(raise_error(SystemExit))
    end

    context "when user decides to regenerate the message (R)" do
      let(:new_commit_message) { {"subject" => "New subject", "description" => "New description"} }

      it "regenerates commit message" do
        expect(ai_client).to receive(:get_commit_message).with("diff").exactly(2).times
          .and_return(commit_message, new_commit_message)
        allow(subject).to receive(:gets).and_return("R\n", "Y\n")

        expect(git_client).to receive(:commit_all).with(new_commit_message)
        expect { subject.run }.to output(/Regenerating/).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when user decides to enter a new message (N)" do
      it "allows user to overwrite commit message" do
        expect(ai_client).to receive(:get_commit_message).with("diff").and_return(commit_message)
        allow(subject).to receive(:gets).and_return("N\n", "user entered message\n", "Y\n")

        expect(git_client).to receive(:commit_all).with("user entered message")
        expect { subject.run }.to output(/Please enter your new commit_message/).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when user quits (Q)" do
      it "exits without committing" do
        expect(ai_client).to receive(:get_commit_message).with("diff").and_return(commit_message)
        allow(subject).to receive(:gets).and_return("Q\n")

        expect { subject.run }.to output(/Quit without committing/).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when input is not Y, R, N, Q" do
      it "shows warning message and loops again" do
        expect(ai_client).to receive(:get_commit_message).with("diff").and_return(commit_message)
        allow(subject).to receive(:gets).and_return("invalid\n", "Y\n")

        expect(git_client).to receive(:commit_all).with(commit_message)
        expect { subject.run }.to output(/Invalid command/).to_stdout.and(raise_error(SystemExit))
      end
    end
  end
end
