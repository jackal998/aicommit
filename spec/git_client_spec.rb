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

  describe "#git_diff_str" do
    context "when there are no changes" do
      it "puts error message and exits program" do
        allow(subject).to receive(:`).with("git diff --staged").and_return("")
        expect { subject.git_diff_str }.to output("No changes detected, exiting program.\n").to_stdout.and raise_error(SystemExit)
      end
    end

    context "when there are changes" do
      it "returns the git diff string" do
        allow(subject).to receive(:`).with("git diff --staged").and_return("diff content")
        expect(subject.git_diff_str).to eq("diff content")
      end
    end
  end

  describe "#commit_all" do
    it "calls the git commit command with the message" do
      expect(subject).to receive(:`).with('git commit -m "test message"')
      subject.commit_all("test message")
    end
  end
end
