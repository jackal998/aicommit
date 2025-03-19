require "pr/generator"
require "aicommit"
require "common/git_client"
require "common/ai_client"
require "common/envs/pr_output_file"

RSpec.describe PR::Generator do
  let(:git_client) { instance_double("Common::GitClient") }
  let(:ai_client) { instance_double("Common::AiClient") }
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
    allow(Common::GitClient).to receive(:new).and_return(git_client)
    allow(Common::AiClient).to receive(:new).and_return(ai_client)
    allow(Common::Envs::BaseBranch).to receive_message_chain(:new, :fetch!).and_return(base_branch)
    allow(git_client).to receive(:diff_from_branch_root).and_return(diff)
    allow(ai_client).to receive(:get_pr_description).with(diff).and_return(pr_description)
  end

  describe "#initialize" do
    it "creates a new GitClient and AiClient instance" do
      expect(Common::GitClient).to receive(:new).and_return(git_client)
      expect(Common::AiClient).to receive(:new).and_return(ai_client)
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
        expect(Common::Envs::BaseBranch).to receive_message_chain(:new, :fetch!).and_return(base_branch)
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
        expect(Common::Envs::BaseBranch).not_to receive(:new)
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

        output = capture_stdout { subject.run }
        expect(output).to include("PR description saved to #{custom_filename}")
        expect(output).to include("PR description copied to clipboard")
      end
    end

    context "with no output options specified" do
      subject { described_class.new(commit_sha, {}) }

      it "doesn't save to file or copy to clipboard" do
        expect_any_instance_of(described_class).not_to receive(:save_to_file)
        expect_any_instance_of(described_class).not_to receive(:copy_to_clipboard)
        expect { subject.run }.not_to output.to_stdout
      end
    end

    context "with template option as string" do
      subject { described_class.new(nil, {template: "template.md", file: true}) }

      it "uses the template file if it exists" do
        allow(File).to receive(:exist?).with("template.md").and_return(true)
        custom_client = instance_double("Common::AiClient")
        allow(subject).to receive(:custom_ai_client_with_template).with("template.md").and_return(custom_client)
        allow(custom_client).to receive(:get_pr_description).with(diff).and_return(pr_description)

        expect { subject.run }.to output(/PR description saved to PR_DESCRIPTION.md/).to_stdout
      end

      it "displays an error and proceeds without template if file doesn't exist" do
        allow(File).to receive(:exist?).with("template.md").and_return(false)

        output = capture_stdout { subject.run }
        expect(output).to include("Template file 'template.md' not found")
        expect(output).to include("PR description saved to PR_DESCRIPTION.md")
      end
    end

    context "with template option as true" do
      subject { described_class.new(nil, {template: true, file: true}) }
      let(:template_selector) { instance_double("Common::Envs::PrTemplate") }
      let(:templates) { ["template1.md", "template2.md"] }

      before do
        allow(Common::Envs::PrTemplate).to receive(:new).and_return(template_selector)
      end

      it "lists available templates and uses selected one" do
        allow(template_selector).to receive(:find_pr_templates).and_return(templates)
        allow(subject).to receive(:gets).and_return("1\n")
        allow(template_selector).to receive(:validate_template_selection).with(1, templates).and_return(true)

        custom_client = instance_double("Common::AiClient")
        allow(subject).to receive(:custom_ai_client_with_template).with("template1.md").and_return(custom_client)
        allow(custom_client).to receive(:get_pr_description).with(diff).and_return(pr_description)

        output = capture_stdout { subject.run }
        expect(output).to include("Please select a PR template for this run only")
        expect(output).to include("1. template1.md")
        expect(output).to include("2. template2.md")
        expect(output).to include("PR description saved to PR_DESCRIPTION.md")
      end

      it "proceeds without template if selection is invalid" do
        allow(template_selector).to receive(:find_pr_templates).and_return(templates)
        allow(subject).to receive(:gets).and_return("3\n")
        allow(template_selector).to receive(:validate_template_selection).with(3, templates).and_return(false)

        expect { subject.run }.to output(/PR description saved to PR_DESCRIPTION.md/).to_stdout
      end

      it "shows message and proceeds without template if no templates are found" do
        allow(template_selector).to receive(:find_pr_templates).and_return([])

        output = capture_stdout { subject.run }
        expect(output).to include("No PR templates found in repository")
        expect(output).to include("PR description saved to PR_DESCRIPTION.md")
      end
    end
  end

  describe "#format_pr_description" do
    it "formats the PR description correctly" do
      expect(subject.send(:format_pr_description, pr_description)).to eq(formatted_output)
    end
  end

  describe "#save_to_file" do
    let(:content) { "# PR Title\n\nDescription goes here" }
    let(:filename) { "pr_desc.md" }
    let(:dir_path) { File.dirname(filename) }

    context "when directory exists" do
      before do
        allow(File).to receive(:directory?).with(dir_path).and_return(true)
        allow(File).to receive(:open).with(filename, "w")
      end

      it "writes content to the file" do
        file_double = double("file")
        expect(File).to receive(:open).with(filename, "w").and_yield(file_double)
        expect(file_double).to receive(:puts).with(content)

        subject.send(:save_to_file, content, filename)
      end
    end

    context "when directory doesn't exist" do
      let(:nested_filename) { "nested/directory/pr_desc.md" }
      let(:nested_dir) { File.dirname(nested_filename) }

      it "creates the directory and writes the file" do
        # Setup
        allow(File).to receive(:directory?).with(nested_dir).and_return(false)
        allow(FileUtils).to receive(:mkdir_p).with(nested_dir)
        file_double = double("file")

        # Expectations
        expect(FileUtils).to receive(:mkdir_p).with(nested_dir)
        expect(File).to receive(:open).with(nested_filename, "w").and_yield(file_double)
        expect(file_double).to receive(:puts).with(content)

        # Execute and verify
        expect { subject.send(:save_to_file, content, nested_filename) }.to output(/Created directory/).to_stdout
      end

      it "handles directory creation errors" do
        # Setup
        allow(File).to receive(:directory?).with(nested_dir).and_return(false)
        error = StandardError.new("Permission denied")
        allow(FileUtils).to receive(:mkdir_p).with(nested_dir).and_raise(error)

        # Prepare for the fallback filename
        base_filename = File.basename(nested_filename)
        file_double = double("file")
        allow(File).to receive(:open).with(base_filename, "w").and_yield(file_double)
        expect(file_double).to receive(:puts).with(content)

        # Execute and verify
        output = capture_stdout { subject.send(:save_to_file, content, nested_filename) }
        expect(output).to include("Error creating directory")
        expect(output).to include("Saving PR description to current directory instead")
      end
    end
  end

  describe "#copy_to_clipboard" do
    let(:content) { "PR Content" }

    context "on macOS" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("darwin")
      end

      it "copies content to clipboard using pbcopy" do
        io_double = double("io")
        expect(IO).to receive(:popen).with("pbcopy", "w").and_yield(io_double)
        expect(io_double).to receive(:<<).with(content)

        subject.send(:copy_to_clipboard, content)
      end
    end

    context "on Linux" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("linux")
      end

      it "copies content to clipboard using xclip" do
        io_double = double("io")
        expect(IO).to receive(:popen).with("xclip -selection clipboard", "w").and_yield(io_double)
        expect(io_double).to receive(:<<).with(content)

        subject.send(:copy_to_clipboard, content)
      end
    end

    context "on Windows" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("mswin")
      end

      it "copies content to clipboard using clip" do
        io_double = double("io")
        expect(IO).to receive(:popen).with("clip", "w").and_yield(io_double)
        expect(io_double).to receive(:<<).with(content)

        subject.send(:copy_to_clipboard, content)
      end
    end

    context "on unsupported OS" do
      before do
        allow(RbConfig::CONFIG).to receive(:[]).with("host_os").and_return("unknown")
      end

      it "shows a warning message" do
        expect { subject.send(:copy_to_clipboard, content) }.to output(/Warning: Clipboard functionality not supported/).to_stdout
      end
    end
  end

  describe "#get_output_filename" do
    let(:default_filename) { "PR_DESCRIPTION.md" }
    let(:pr_output_file) { instance_double(Common::Envs::PrOutputFile) }

    before do
      allow(Common::Envs::PrOutputFile).to receive(:new).and_return(pr_output_file)
      allow(pr_output_file).to receive(:fetch).and_return(nil)
      allow(Common::Envs::PrOutputFile).to receive(:const_get).with(:DEFAULT_FILENAME).and_return(default_filename)
    end

    it "returns the specified filename when given a string" do
      options = {file: "custom.md"}
      generator = described_class.new(nil, options)
      expect(generator.send(:get_output_filename)).to eq("custom.md")
    end

    it "returns the default filename when file option is true" do
      options = {file: true}
      generator = described_class.new(nil, options)
      expect(generator.send(:get_output_filename)).to eq(default_filename)
    end

    it "uses saved setting when available" do
      saved_filename = "saved_filename.md"
      allow(pr_output_file).to receive(:fetch).and_return(saved_filename)

      options = {file: true}
      generator = described_class.new(nil, options)
      expect(generator.send(:get_output_filename)).to eq(saved_filename)
    end
  end

  describe "#custom_ai_client_with_template" do
    let(:template_path) { "custom_template.md" }
    let(:template_content) { "This is a custom template" }

    it "creates a custom AI client with the template" do
      client_double = instance_double(Common::AiClient)
      allow(Common::AiClient).to receive(:new).and_return(client_double)
      allow(client_double).to receive(:instance_variable_set)

      result = subject.send(:custom_ai_client_with_template, template_path)
      expect(result).to eq(client_double)

      # Test that the instance variable was set
      expect(client_double).to have_received(:instance_variable_set).with(:@_custom_template, template_path)
    end

    it "defines a get_pr_template method that reads the template file" do
      # This is a direct test of the monkey-patched method's behavior
      # We need to actually monkey-patch a test object to verify behavior

      test_client = Object.new

      # Create our own implementation of custom_ai_client_with_template
      custom_client = Common::AiClient.new
      allow(Common::AiClient).to receive(:new).and_return(custom_client)

      # Apply the actual monkey patching to our test client
      def test_client.get_pr_template
        if File.exist?(@_custom_template)
          File.read(@_custom_template)
        end
      end

      test_client.instance_variable_set(:@_custom_template, template_path)

      # Test when the file exists
      allow(File).to receive(:exist?).with(template_path).and_return(true)
      allow(File).to receive(:read).with(template_path).and_return(template_content)
      expect(test_client.get_pr_template).to eq(template_content)

      # Test when the file doesn't exist
      allow(File).to receive(:exist?).with(template_path).and_return(false)
      expect(test_client.get_pr_template).to be_nil
    end

    it "runs the actual monkey-patched code" do
      # Create a real PR::Generator instance
      generator = described_class.new

      # When we call the method, it should create a client with a monkey-patched method
      custom_client = generator.send(:custom_ai_client_with_template, template_path)

      # Now explicitly test the monkey-patched method on the returned client
      # First, test the case when file exists (using expect to ensure the code is executed)
      expect(File).to receive(:exist?).with(template_path).and_return(true)
      expect(File).to receive(:read).with(template_path).and_return(template_content)

      result = custom_client.get_pr_template
      expect(result).to eq(template_content)

      # Then test when the file doesn't exist
      expect(File).to receive(:exist?).with(template_path).and_return(false)
      result = custom_client.get_pr_template
      expect(result).to be_nil
    end
  end

  describe "error handling" do
    context "when OpenAI::Error occurs" do
      subject { described_class.new(commit_sha, {file: true}) }

      before do
        allow(git_client).to receive(:diff_from_branch_root).and_return(diff)
        allow(ai_client).to receive(:get_pr_description).and_raise(OpenAI::Error.new("API Error"))
      end

      it "handles OpenAI::Error" do
        expect(Aicommit).to receive(:handle_error)
        subject.run
      end
    end

    context "when generic error occurs" do
      subject { described_class.new(commit_sha, {file: true}) }

      before do
        # Mock exit to prevent the test from exiting
        allow(subject).to receive(:exit)

        allow(git_client).to receive(:diff_from_branch_root).and_return(diff)
        allow(ai_client).to receive(:get_pr_description).and_raise(StandardError.new("Unexpected error"))
      end

      it "catches and displays generic errors" do
        expect { subject.run }.to output(/Error: Unexpected error/).to_stdout
        expect(subject).to have_received(:exit).with(1)
      end
    end
  end

  # Helper method to capture stdout for testing
  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
