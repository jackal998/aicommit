require "git"
require "git_client"

RSpec.describe GitClient do
  describe "#initialize" do
    context "when not in a git repository" do
      it "puts error message and exits program" do
        allow(Dir).to receive(:exist?).with(".git").and_return(false)
        expect { subject }.to output("Not a git repository!\n").to_stdout.and raise_error(SystemExit)
      end
    end

    context "when in a git repository" do
      it "sets @git" do
        allow(Dir).to receive(:exist?).with(".git").and_return(true)
        expect(Git).to receive(:open).with(".").and_return("git object")
        expect(subject.instance_variable_get(:@git)).to eq("git object")
      end
    end
  end

  describe "#get_patch_str" do
    before do
      allow(subject).to receive(:current_branch).and_return(current_branch)
    end

    context "when current_branch not present" do
      let(:current_branch) { nil }

      it "puts error message and exits program" do
        expect { subject.get_patch_str }.to output("No HEAD detected, please add your first commit, exiting program.\n").to_stdout.and raise_error(SystemExit)
      end
    end

    context "when current_branch present" do
      let(:current_branch) { "master" }
      let(:path) { "file.rb" }
      let(:patch) { "diff content" }

      before do
        git_diff = instance_double(Git::Diff)
        allow(subject.instance_variable_get(:@git)).to receive(:diff).and_return(git_diff)

        diff = double("diff", path: path, patch: patch)
        allow(git_diff).to receive(:each).and_yield(diff)
      end

      it "grep all the git diff into a patch_str" do
        patch_str = subject.get_patch_str
        expect(patch_str).to include("file.rb").and include("diff content")
      end

      context "when patch_str is nil or blank" do
        let(:path) { "" }
        let(:patch) { "" }

        it "puts error message" do
          expect { subject.get_patch_str }.to output("No changes detected, exiting program.\n").to_stdout.and raise_error(SystemExit)
        end
      end

      context "when patch_str present" do
        it "returns patch_str" do
          expect(subject.get_patch_str).to eq("\n\nfile.rb\ndiff content")
        end
      end
    end
  end
end
