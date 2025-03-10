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
    let(:base_branch) { "develop" }
    let(:commit_sha) { "abc123def456" }
    let(:short_sha) { "abc123d" }
    let(:merge_base) { "xyz789" }
    let(:diff_content) { "diff content from branch root" }

    before do
      allow(subject).to receive(:`).with("git merge-base HEAD #{base_branch}").and_return("#{merge_base}\n")
    end

    context "when merge base cannot be determined" do
      it "puts error message and exits program" do
        allow(subject).to receive(:is_commit_sha?).with(base_branch).and_return(false)
        allow(subject).to receive(:`).with("git merge-base HEAD #{base_branch}").and_return("")
        expect { subject.diff_from_branch_root(base_branch) }.to output(/Couldn't determine base commit relative to #{base_branch}/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when there are no changes between branch root and HEAD" do
      it "puts error message and exits program" do
        allow(subject).to receive(:is_commit_sha?).with(base_branch).and_return(false)
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return("")
        expect { subject.diff_from_branch_root(base_branch) }.to output(/No changes detected between base commit and HEAD/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when there are changes between branch root and HEAD" do
      it "returns the git diff string" do
        allow(subject).to receive(:is_commit_sha?).with(base_branch).and_return(false)
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root(base_branch)).to eq(diff_content)
      end
    end

    context "when default base branch is used" do
      it "uses 'main' as the default branch name" do
        allow(subject).to receive(:is_commit_sha?).with("main").and_return(false)
        allow(subject).to receive(:`).with("git merge-base HEAD main").and_return("#{merge_base}\n")
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root).to eq(diff_content)
      end
    end

    context "when a commit SHA is provided" do
      before do
        allow(subject).to receive(:is_commit_sha?).with(commit_sha).and_return(true)
        allow(subject).to receive(:`).with("git diff #{commit_sha} HEAD").and_return(diff_content)
      end

      it "uses the SHA directly without finding a merge base" do
        expect(subject).not_to receive(:`).with("git merge-base HEAD #{commit_sha}")
        expect(subject.diff_from_branch_root(commit_sha)).to eq(diff_content)
      end
    end

    context "when a short SHA is provided" do
      before do
        allow(subject).to receive(:is_commit_sha?).with(short_sha).and_return(true)
        allow(subject).to receive(:`).with("git diff #{short_sha} HEAD").and_return(diff_content)
      end

      it "uses the short SHA directly without finding a merge base" do
        expect(subject).not_to receive(:`).with("git merge-base HEAD #{short_sha}")
        expect(subject.diff_from_branch_root(short_sha)).to eq(diff_content)
      end
    end
  end

  describe "#is_commit_sha?" do
    it "returns true for a full-length commit SHA" do
      ref = "abcdef1234567890abcdef1234567890abcdef12"
      allow(subject).to receive(:`).with("git cat-file -t #{ref}").and_return("commit\n")
      expect(subject.send(:is_commit_sha?, ref)).to be true
    end

    it "returns true for a shortened commit SHA" do
      ref = "abcdef123456"
      allow(subject).to receive(:`).with("git cat-file -t #{ref}").and_return("commit\n")
      expect(subject.send(:is_commit_sha?, ref)).to be true
    end

    it "returns false for a branch name" do
      ref = "main"
      expect(subject.send(:is_commit_sha?, ref)).to be false
    end

    it "returns false for a SHA-like string that isn't a commit" do
      ref = "abcdef1234567890abcdef1234567890abcdef12"
      allow(subject).to receive(:`).with("git cat-file -t #{ref}").and_return("blob\n")
      expect(subject.send(:is_commit_sha?, ref)).to be false
    end

    it "returns false for a SHA-like string that doesn't exist" do
      ref = "abcdef1234567890abcdef1234567890abcdef12"
      allow(subject).to receive(:`).with("git cat-file -t #{ref}").and_return("")
      expect(subject.send(:is_commit_sha?, ref)).to be false
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
