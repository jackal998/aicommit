require "pr_description_generator"
require "git_client"
require "ai_client"

RSpec.describe PrDescriptionGenerator do
  let(:git_client) { instance_double("GitClient") }
  let(:ai_client) { instance_double("AiClient") }
  let(:base_branch) { "develop" }
  let(:commit_sha) { "abc123def456" }
  let(:diff) { "sample diff content" }
  let(:pr_description) do
    {
      "title" => "Implement new feature",
      "description" => "## Overview\nThis PR implements a new feature.\n\n## Changes\n- Added feature X\n- Fixed bug Y"
    }
  end
  let(:formatted_output) { "# #{pr_description["title"]}\n\n#{pr_description["description"]}" }

  before do
    allow(GitClient).to receive(:new).and_return(git_client)
    allow(AiClient).to receive(:new).and_return(ai_client)
    allow(Envs::BaseBranch).to receive_message_chain(:new, :fetch!).and_return(base_branch)
    allow(git_client).to receive(:diff_from_branch_root).and_return(diff)
    allow(ai_client).to receive(:get_pr_description).with(diff).and_return(pr_description)
  end

  describe "#initialize" do
    it "creates a new GitClient and AiClient instance" do
      expect(GitClient).to receive(:new).and_return(git_client)
      expect(AiClient).to receive(:new).and_return(ai_client)
      subject
    end

    context "with base_ref parameter" do
      subject { described_class.new(commit_sha) }

      it "stores the base_ref parameter" do
        expect(subject.instance_variable_get(:@base_ref)).to eq(commit_sha)
      end
    end

    context "with options parameter" do
      let(:options) { {file: "custom.md", clipboard: true} }
      subject { described_class.new(commit_sha, options) }

      it "stores the options" do
        expect(subject.instance_variable_get(:@options)).to eq(options)
      end
    end
  end

  describe "#run" do
    before do
      allow(File).to receive(:open).and_yield(StringIO.new)
      allow(StringIO.new).to receive(:puts)
      allow_any_instance_of(described_class).to receive(:copy_to_clipboard)
    end

    context "when no base_ref is specified in the constructor" do
      subject { described_class.new(nil, {file: true}) }

      before do
        allow(git_client).to receive(:diff_from_branch_root).with(base_branch).and_return(diff)
      end

      it "uses the configured base branch" do
        expect(Envs::BaseBranch).to receive_message_chain(:new, :fetch!).and_return(base_branch)
        expect(git_client).to receive(:diff_from_branch_root).with(base_branch).and_return(diff)
        expect(ai_client).to receive(:get_pr_description).with(diff).and_return(pr_description)

        expect { subject.run }.to output(/PR description saved to PR_DESCRIPTION.md/).to_stdout
      end
    end

    context "when a base_ref is specified in the constructor" do
      subject { described_class.new(commit_sha, {file: true}) }

      before do
        allow(git_client).to receive(:diff_from_branch_root).with(commit_sha).and_return(diff)
      end

      it "uses the specified base_ref" do
        expect(Envs::BaseBranch).not_to receive(:new)
        expect(git_client).to receive(:diff_from_branch_root).with(commit_sha).and_return(diff)
        expect(ai_client).to receive(:get_pr_description).with(diff).and_return(pr_description)

        expect { subject.run }.to output(/PR description saved to PR_DESCRIPTION.md/).to_stdout
      end
    end

    context "with file option as true" do
      subject { described_class.new(commit_sha, {file: true}) }

      it "saves to default file" do
        expect_any_instance_of(described_class).to receive(:save_to_file).with(formatted_output, "PR_DESCRIPTION.md")
        expect { subject.run }.to output(/PR description saved to PR_DESCRIPTION.md/).to_stdout
      end
    end

    context "with file option as string" do
      let(:custom_filename) { "custom_pr.md" }
      subject { described_class.new(commit_sha, {file: custom_filename}) }

      it "saves to specified file" do
        expect_any_instance_of(described_class).to receive(:save_to_file).with(formatted_output, custom_filename)
        expect { subject.run }.to output(/PR description saved to #{custom_filename}/).to_stdout
      end
    end

    context "with clipboard option" do
      subject { described_class.new(commit_sha, {clipboard: true}) }

      it "copies to clipboard" do
        expect_any_instance_of(described_class).to receive(:copy_to_clipboard).with(formatted_output)
        expect { subject.run }.to output(/PR description copied to clipboard/).to_stdout
      end
    end

    context "with both file and clipboard options" do
      let(:custom_filename) { "custom_pr.md" }
      subject { described_class.new(commit_sha, {file: custom_filename, clipboard: true}) }

      it "saves to file and copies to clipboard" do
        expect_any_instance_of(described_class).to receive(:save_to_file).with(formatted_output, custom_filename)
        expect_any_instance_of(described_class).to receive(:copy_to_clipboard).with(formatted_output)
        expect { subject.run }.to output(/PR description saved to #{custom_filename}/).to_stdout
      end
    end
  end

  describe "#format_pr_description" do
    it "formats the PR description correctly" do
      expect(subject.send(:format_pr_description, pr_description)).to eq(formatted_output)
    end
  end

  describe "#save_to_file" do
    let(:file) { instance_double(File) }
    let(:filename) { "output.md" }

    before do
      allow(File).to receive(:open).and_yield(file)
      allow(file).to receive(:puts)
    end

    it "writes the content to the specified file" do
      expect(File).to receive(:open).with(filename, "w")
      expect(file).to receive(:puts).with(formatted_output)

      subject.send(:save_to_file, formatted_output, filename)
    end
  end

  describe "#copy_to_clipboard" do
    let(:content) { "Test content" }
    let(:io) { instance_double(IO) }

    context "on macOS" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("darwin")
        allow(IO).to receive(:popen).with("pbcopy", "w").and_yield(io)
        allow(io).to receive(:<<)
      end

      it "uses pbcopy" do
        expect(IO).to receive(:popen).with("pbcopy", "w")
        expect(io).to receive(:<<).with(content)
        subject.send(:copy_to_clipboard, content)
      end
    end

    context "on Linux" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("linux")
        allow(IO).to receive(:popen).with("xclip -selection clipboard", "w").and_yield(io)
        allow(io).to receive(:<<)
      end

      it "uses xclip" do
        expect(IO).to receive(:popen).with("xclip -selection clipboard", "w")
        expect(io).to receive(:<<).with(content)
        subject.send(:copy_to_clipboard, content)
      end
    end

    context "on Windows" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("mswin")
        allow(IO).to receive(:popen).with("clip", "w").and_yield(io)
        allow(io).to receive(:<<)
      end

      it "uses clip" do
        expect(IO).to receive(:popen).with("clip", "w")
        expect(io).to receive(:<<).with(content)
        subject.send(:copy_to_clipboard, content)
      end
    end

    context "on unsupported OS" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("unknown")
      end

      it "shows a warning" do
        expect { subject.send(:copy_to_clipboard, content) }.to output(/Warning: Clipboard functionality not supported/).to_stdout
      end
    end
  end
end
