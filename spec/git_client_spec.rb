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
        expect { subject.staged_changes }.to output(/No changes detected, perhaps you didn't stage any changes/).to_stdout.and raise_error(SystemExit)
      end
    end

    context "when there are changes" do
      it "returns the git diff string" do
        allow(subject).to receive(:`).with("git diff --staged").and_return("diff content")
        expect(subject.staged_changes).to eq("diff content")
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
