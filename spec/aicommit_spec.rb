require "aicommit"

describe Aicommit do
  let(:git_client) { instance_double(GitClient) }
  let(:commit_message_generator) { instance_double(CommitMessageGenerator) }
  let(:token_manager) { instance_double(TokenManager) }

  before do
    allow(GitClient).to receive(:new).and_return(git_client)
    allow(CommitMessageGenerator).to receive(:new).and_return(commit_message_generator)
    allow(TokenManager).to receive(:new).and_return(token_manager)
  end

  describe "#run" do
    context "when invalid api token" do
      before do
        allow(token_manager).to receive(:fetch).with("OPENAI_API_TOKEN").and_return("INVALID_API_KEY", "VALID_API_KEY")
      end

      it "asks for valid api token and save" do
        expect(git_client).to receive(:get_patch_str).and_return("diff")

        expect(CommitMessageGenerator).to receive(:new).with("INVALID_API_KEY").and_return(commit_message_generator)
        expect(CommitMessageGenerator).to receive(:new).with("VALID_API_KEsY").and_return(commit_message_generator)

        expect(commit_message_generator).to receive(:generate).with("diff").and_return({code: 401, result: ""}, {code: 200, result: "commit message"})
        expect(token_manager).to receive(:write!).with("OPENAI_API_TOKEN")

        allow(subject).to receive(:gets).and_return("VALID_API_KEY\n", "Y\n")
        expect(git_client).to receive(:commit_all).with("commit message")

        expect { subject.run }.to output(/Invalid API key./).to_stdout.and(raise_error(SystemExit))
      end
    end

    context "when valid api token" do
      before do
        allow(token_manager).to receive(:fetch).with("OPENAI_API_TOKEN").and_return("API_KEY")
      end

      it "shows hint commit message and ask user if commit or not" do
        expect(git_client).to receive(:get_patch_str).and_return("diff")

        expect(commit_message_generator).to receive(:generate).with("diff").and_return({code: 200, result: "commit message"})

        allow(subject).to receive(:gets).and_return("Y\n")
        expect(git_client).to receive(:commit_all).with("commit message")

        expect { subject.run }.to output(/commit_message: commit message/).to_stdout.and(raise_error(SystemExit))
      end

      context "when input is Y" do
        it "tells user what commit message would be then commit and exit program" do
          expect(git_client).to receive(:get_patch_str).and_return("diff")

          expect(commit_message_generator).to receive(:generate).with("diff").and_return({code: 200, result: "commit message"})

          allow(subject).to receive(:gets).and_return("Y\n")
          expect(git_client).to receive(:commit_all).with("commit message")

          expect { subject.run }.to output(/Committed all changes with message: commit message/).to_stdout.and(raise_error(SystemExit))
        end
      end

      context "when input is R" do
        it "regenerates commit message" do
          expect(git_client).to receive(:get_patch_str).and_return("diff")
          expect(commit_message_generator).to receive(:generate).with("diff").and_return({code: 200, result: "commit message"}, {code: 200, result: "new commit message"})

          allow(subject).to receive(:gets).and_return("R\n", "Y\n")
          expect(git_client).to receive(:commit_all).with("new commit message")

          expect { subject.run }.to output(/commit_message: new commit message/).to_stdout.and(raise_error(SystemExit))
        end
      end

      context "when input is N" do
        it "allows user to overwrite commit message" do
          expect(git_client).to receive(:get_patch_str).and_return("diff")
          expect(commit_message_generator).to receive(:generate).with("diff").and_return({code: 200, result: "commit message"})

          allow(subject).to receive(:gets).and_return("N\n", "new commit message\n", "Y\n")
          expect(git_client).to receive(:commit_all).with("new commit message")

          expect { subject.run }.to output(/commit_message: new commit message/).to_stdout.and(raise_error(SystemExit))
        end
      end

      context "when input is Q" do
        it "quits without commit" do
          expect(git_client).to receive(:get_patch_str).and_return("diff")
          expect(commit_message_generator).to receive(:generate).with("diff").and_return({code: 200, result: "commit message"})

          allow(subject).to receive(:gets).and_return("Q\n")

          expect { subject.run }.to output(/Quit without committing/).to_stdout.and(raise_error(SystemExit))
        end
      end

      context "when input is not Y, R, N, Q" do
        it "shows warning message and loops again" do
          expect(git_client).to receive(:get_patch_str).and_return("diff")

          allow(subject).to receive(:gets).and_return("invalid\n", "Y\n")
          expect(commit_message_generator).to receive(:generate).with("diff").and_return({code: 200, result: "commit message"})
          expect(git_client).to receive(:commit_all).with("commit message")

          expect { subject.run }.to output(/Invalid command/).to_stdout.and(raise_error(SystemExit))
        end
      end
    end
  end
end
