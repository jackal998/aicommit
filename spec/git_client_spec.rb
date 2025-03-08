require "git_client"

RSpec.describe GitClient do
  describe "#initialize" do
    context "when not in a git repository" do
      it "puts error message and exits program" do
        allow(Dir).to receive(:exist?).with(".git").and_return(false)
        expect { subject }.to output(/Not a git repository!/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when in a git repository" do
      it "does not raise an error" do
        allow(Dir).to receive(:exist?).with(".git").and_return(true)
        expect { subject }.not_to raise_error
      end
    end
  end

  describe "#staged_changes" do
    context "when there are no changes" do
      it "puts error message and exits program" do
        allow(subject).to receive(:`).with("git diff --staged").and_return("")
        expect { subject.staged_changes }.to output(/No changes detected, perhaps you didn't stage any changes?/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when there are changes" do
      it "returns the git diff string" do
        allow(subject).to receive(:`).with("git diff --staged").and_return("diff content")
        expect(subject.staged_changes).to eq("diff content")
      end
    end
  end

  describe "#diff_from_branch_root" do
    let(:main_branch) { "master" }
    let(:merge_base) { "abc123" }
    let(:diff_content) { "diff content from branch root" }

    before do
      allow(subject).to receive(:`).with("git merge-base HEAD #{main_branch}").and_return("#{merge_base}\n")
    end

    context "when merge base cannot be determined" do
      it "puts error message and exits program" do
        allow(subject).to receive(:`).with("git merge-base HEAD #{main_branch}").and_return("")
        expect { subject.diff_from_branch_root(main_branch) }.to output(/Couldn't determine branch root relative to #{main_branch}/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when there are no changes between branch root and HEAD" do
      it "puts error message and exits program" do
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return("")
        expect { subject.diff_from_branch_root(main_branch) }.to output(/No changes detected between branch root and HEAD/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when there are changes between branch root and HEAD" do
      it "returns the git diff string" do
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root(main_branch)).to eq(diff_content)
      end
    end

    context "when default main branch is used" do
      it "uses 'main' as the default branch name" do
        allow(subject).to receive(:`).with("git merge-base HEAD main").and_return("#{merge_base}\n")
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root).to eq(diff_content)
      end
    end
  end

  describe "#commit_all" do
    let(:commit_message) { {"subject" => "Test subject", "description" => "Test description"} }

    it "calls the git commit command with the subject and description" do
      expect(subject).to receive(:`).with('git commit -m "Test subject" -m "Test description"')
      subject.commit_all(commit_message)
    end
  end
end
