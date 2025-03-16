require "common/git_client"
require "open3"

RSpec.describe Common::GitClient do
  describe "#initialize" do
    context "when not in a git repository" do
      it "puts error message and exits program" do
        allow(Dir).to receive(:exist?).with(".git").and_return(false)
        expect_any_instance_of(String).to receive(:red).and_return("Not a git repository!")
        expect { subject }.to output(/Not a git repository!/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when in a git repository" do
      before do
        allow(Dir).to receive(:exist?).with(".git").and_return(true)
      end

      it "does not raise an error" do
        expect { subject }.not_to raise_error
      end

      it "creates a valid git client instance" do
        client = Common::GitClient.new
        expect(client).to be_an_instance_of(Common::GitClient)
      end
    end
  end

  describe "#staged_changes" do
    before do
      allow(Dir).to receive(:exist?).with(".git").and_return(true)
    end

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

      it "returns correctly formatted git diff output" do
        diff_output = "diff --git a/file.rb b/file.rb\nindex 1234567..abcdef0 100644\n--- a/file.rb\n+++ b/file.rb\n@@ -1,3 +1,4 @@\n line1\n+new line\n line2\n line3"
        allow(subject).to receive(:`).with("git diff --staged").and_return(diff_output)
        expect(subject.staged_changes).to eq(diff_output)
      end
    end
  end

  describe "#diff_from_branch_root" do
    before do
      allow(Dir).to receive(:exist?).with(".git").and_return(true)
    end

    let(:base_branch) { "develop" }
    let(:commit_sha) { "abc123def456" }
    let(:short_sha) { "abc123d" }
    let(:merge_base) { "xyz789" }
    let(:diff_content) { "diff content from branch root" }

    context "when using default base branch" do
      it "uses 'main' as the default branch name" do
        allow(subject).to receive(:is_commit_sha?).with("main").and_return(false)
        allow(subject).to receive(:`).with("git merge-base HEAD main").and_return("#{merge_base}\n")
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root).to eq(diff_content)
      end
    end

    context "when using a branch name" do
      before do
        allow(subject).to receive(:is_commit_sha?).with(base_branch).and_return(false)
        allow(subject).to receive(:`).with("git merge-base HEAD #{base_branch}").and_return("#{merge_base}\n")
      end

      it "determines merge base between HEAD and the branch" do
        allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root(base_branch)).to eq(diff_content)
      end

      context "when merge base cannot be determined" do
        it "puts error message and exits program" do
          allow(subject).to receive(:`).with("git merge-base HEAD #{base_branch}").and_return("")
          expect { subject.diff_from_branch_root(base_branch) }.to output(/Couldn't determine base commit relative to #{base_branch}/).to_stdout.and raise_error(SystemExit)
        end
      end

      context "when there are no changes between branch root and HEAD" do
        it "puts error message and exits program" do
          allow(subject).to receive(:`).with("git diff #{merge_base} HEAD").and_return("")
          expect { subject.diff_from_branch_root(base_branch) }.to output(/No changes detected between base commit and HEAD/).to_stdout.and raise_error(SystemExit)
        end
      end
    end

    context "when using a commit SHA" do
      before do
        allow(subject).to receive(:is_commit_sha?).with(commit_sha).and_return(true)
      end

      it "uses the SHA directly without finding a merge base" do
        allow(subject).to receive(:`).with("git diff #{commit_sha} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root(commit_sha)).to eq(diff_content)
      end

      context "when there are no changes between SHA and HEAD" do
        it "puts error message and exits program" do
          allow(subject).to receive(:`).with("git diff #{commit_sha} HEAD").and_return("")
          expect { subject.diff_from_branch_root(commit_sha) }.to output(/No changes detected between base commit and HEAD/).to_stdout.and raise_error(SystemExit)
        end
      end
    end

    context "with short commit SHA" do
      before do
        allow(subject).to receive(:is_commit_sha?).with(short_sha).and_return(true)
      end

      it "uses the short SHA directly without finding a merge base" do
        allow(subject).to receive(:`).with("git diff #{short_sha} HEAD").and_return(diff_content)
        expect(subject.diff_from_branch_root(short_sha)).to eq(diff_content)
      end
    end
  end

  describe "#commit_all" do
    before do
      allow(Dir).to receive(:exist?).with(".git").and_return(true)
    end

    let(:commit_message) { {"subject" => "Test subject", "description" => "Test description"} }

    it "calls the git commit command with the subject and description" do
      expect(subject).to receive(:`).with('git commit -m "Test subject" -m "Test description"')
      subject.commit_all(commit_message)
    end

    it "handles commit messages with special characters" do
      special_message = {"subject" => "Subject with 'quotes'", "description" => "Description with 'quotes'"}
      expect(subject).to receive(:`).with('git commit -m "Subject with \'quotes\'" -m "Description with \'quotes\'"')
      subject.commit_all(special_message)
    end

    it "returns the command output" do
      output = "some git commit output"
      allow(subject).to receive(:`).with('git commit -m "Test subject" -m "Test description"').and_return(output)
      expect(subject.commit_all(commit_message)).to eq(output)
    end
  end

  describe "#branch_exists?" do
    before do
      allow(Dir).to receive(:exist?).with(".git").and_return(true)
    end

    context "with invalid inputs" do
      it "returns false for nil branch name" do
        expect(subject.branch_exists?(nil)).to be false
      end

      it "returns false for empty branch name" do
        expect(subject.branch_exists?("")).to be false
      end
    end

    context "with valid branch name" do
      it "returns true when branch exists" do
        branch_name = "main"
        # Mock the verify_branch method to return true
        expect(subject).to receive(:verify_branch).with(branch_name).and_return(true)
        expect(subject.branch_exists?(branch_name)).to be true
      end

      it "checks if it's a commit SHA when branch doesn't exist" do
        branch_name = "non-existent-branch"
        # Mock the verify_branch method to return false
        expect(subject).to receive(:verify_branch).with(branch_name).and_return(false)
        # Should check if it's a commit SHA
        expect(subject).to receive(:is_commit_sha?).with(branch_name).and_return(false)
        expect(subject.branch_exists?(branch_name)).to be false
      end

      it "returns true when it's a valid commit SHA even if not a branch" do
        sha = "1234567"
        # Mock the verify_branch method to return false
        expect(subject).to receive(:verify_branch).with(sha).and_return(false)
        # But it is a valid commit SHA
        expect(subject).to receive(:is_commit_sha?).with(sha).and_return(true)
        expect(subject.branch_exists?(sha)).to be true
      end
    end
  end

  describe "#exit_program" do
    before do
      allow(Dir).to receive(:exist?).with(".git").and_return(true)
    end

    it "prints the message and exits" do
      expect(subject).to receive(:puts).with("Test error message")
      expect(subject).to receive(:puts).with("exiting program.")
      expect { subject.send(:exit_program, "Test error message") }.to raise_error(SystemExit)
    end
  end

  describe "#verify_branch" do
    before do
      allow(Dir).to receive(:exist?).with(".git").and_return(true)
    end

    it "calls system with git rev-parse command" do
      branch_name = "main"
      expect(subject).to receive(:system).with("git rev-parse --verify #{branch_name} > /dev/null 2>&1").and_return(true)
      expect(subject.send(:verify_branch, branch_name)).to be true
    end
  end

  describe "#is_commit_sha?" do
    before do
      allow(Dir).to receive(:exist?).with(".git").and_return(true)
    end

    context "when input has invalid format" do
      it "returns false for non-hex strings" do
        expect(subject.send(:is_commit_sha?, "ghjklmnop")).to be false
      end

      it "returns false for too short strings" do
        expect(subject.send(:is_commit_sha?, "abc123")).to be false
      end

      it "returns false for empty input" do
        expect(subject.send(:is_commit_sha?, "")).to be false
      end

      it "returns false for nil input" do
        expect(subject.send(:is_commit_sha?, nil)).to be false
      end
    end

    context "when input has valid format" do
      it "returns true for full SHA if git command confirms it's a commit" do
        sha = "1234567890abcdef1234567890abcdef12345678"
        allow(subject).to receive(:`).with("git cat-file -t #{sha}").and_return("commit\n")
        expect(subject.send(:is_commit_sha?, sha)).to be true
      end

      it "returns true for short SHA if git command confirms it's a commit" do
        sha = "1234567"
        allow(subject).to receive(:`).with("git cat-file -t #{sha}").and_return("commit\n")
        expect(subject.send(:is_commit_sha?, sha)).to be true
      end

      it "returns false when git command returns non-commit response" do
        sha = "1234567"
        allow(subject).to receive(:`).with("git cat-file -t #{sha}").and_return("blob\n")
        expect(subject.send(:is_commit_sha?, sha)).to be false
      end

      it "returns false when git command returns empty response" do
        sha = "1234567"
        allow(subject).to receive(:`).with("git cat-file -t #{sha}").and_return("")
        expect(subject.send(:is_commit_sha?, sha)).to be false
      end

      it "returns false when git command returns error response" do
        sha = "1234567"
        allow(subject).to receive(:`).with("git cat-file -t #{sha}").and_return("fatal: Not a valid object name")
        expect(subject.send(:is_commit_sha?, sha)).to be false
      end
    end
  end
end
