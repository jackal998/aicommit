require "spec_helper"
require "tmpdir"
require "fileutils"
require "openai"
require "stringio"

# High-level User Acceptance Tests for Aicommit
# These tests focus on end-to-end user journeys and workflows
RSpec.describe "Aicommit User Acceptance Tests" do
  # Setup helpers
  let(:git_repo_path) { Dir.mktmpdir }
  let(:openai_client) { instance_double(OpenAI::Client) }
  let(:ai_client) { instance_double(Common::AiClient) }
  let(:git_client) { instance_double(Common::GitClient) }

  before do
    # Mock ENV to avoid modifying real environment variables
    stub_const("ENV", {})

    # Setup test environment
    Dir.chdir(git_repo_path) do
      `git init > #{File::NULL} 2>&1`
      `git config user.email "test@example.com" > #{File::NULL} 2>&1`
      `git config user.name "Test User" > #{File::NULL} 2>&1`
      File.write(".gitignore", "")
      File.write("test_file.txt", "Initial content")
      `git add test_file.txt > #{File::NULL} 2>&1`
      `git commit -m "Initial commit" > #{File::NULL} 2>&1`
    end

    # Mock core dependencies used across all tests
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(Common::AiClient).to receive(:new).and_return(ai_client)
    allow(Common::GitClient).to receive(:new).and_return(git_client)

    allow(ai_client).to receive(:verify_api_token!).and_return(true)
  end

  after do
    FileUtils.remove_entry(git_repo_path)
  end

  # Helper method to capture stdout for testing
  def suppress_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
    [$stdout.string, $stderr.string]
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  describe "Essential Configuration Workflow" do
    let(:openai_api_key) { instance_double(Common::Envs::OpenaiApiKey) }
    let(:selected_model) { instance_double(Common::Envs::SelectedModel) }
    let(:base_branch) { instance_double(Common::Envs::BaseBranch) }
    let(:pr_template) { instance_double(Common::Envs::PrTemplate) }

    let(:expected_openai_api_key) { Faker::String.random(length: 10) }
    let(:expected_selected_model) { Faker::String.random(length: 10) }
    let(:expected_base_branch) { Faker::String.random(length: 10) }
    let(:expected_pr_template) { Faker::String.random(length: 10) }

    before do
      # Allow environment file operations for this test
      allow(File).to receive(:write).and_return(nil)
      allow(File).to receive(:read).and_return("")
      allow(File).to receive(:exist?).and_return(true)
      allow(Dotenv).to receive(:load).and_return(nil)
      allow(Dotenv).to receive(:overload!).and_return(nil)

      # Setup environment variable mocks
      allow(Common::Envs::OpenaiApiKey).to receive(:new).and_return(openai_api_key)
      allow(Common::Envs::SelectedModel).to receive(:new).and_return(selected_model)
      allow(Common::Envs::BaseBranch).to receive(:new).and_return(base_branch)
      allow(Common::Envs::PrTemplate).to receive(:new).with(any_args).and_return(pr_template)

      # Allow environment variable fetching
      allow(openai_api_key).to receive(:fetch).and_return(expected_openai_api_key)
      allow(selected_model).to receive(:fetch).and_return(expected_selected_model)
      allow(base_branch).to receive(:fetch).and_return(expected_base_branch)
      allow(pr_template).to receive(:fetch).and_return(expected_pr_template)
    end

    it "completes first-time setup with all required configurations", :acceptance do
      # Expect environment variable updates
      expect(openai_api_key).to receive(:update!).with(expected_openai_api_key).once
      expect(selected_model).to receive(:update!).with(expected_selected_model).once
      expect(base_branch).to receive(:update!).with(expected_base_branch).once
      expect(pr_template).to receive(:update!).once

      # Run complete configuration sequence
      suppress_output { Aicommit.set_openai_api_key(expected_openai_api_key) }
      suppress_output { Aicommit.set_selected_model(expected_selected_model) }
      suppress_output { Aicommit.set_base_branch(expected_base_branch) }
      suppress_output { Aicommit.set_pr_template(expected_pr_template) }

      # Verify configuration
      output, _ = suppress_output { Aicommit.show_config }
      expect(output).to include("OpenAI API Key: #{expected_openai_api_key[0..2]}...#{expected_openai_api_key[-4..]}")
      expect(output).to include("Selected Model: #{expected_selected_model}")
      expect(output).to include("Base Branch: #{expected_base_branch}")
      expect(output).to include("PR Template: #{expected_pr_template}")
    end
  end

  describe "Core Git Operations" do
    context "when there are staged changes" do
      let(:expected_subject) { Faker::Lorem.word }
      let(:expected_description) { Faker::Lorem.paragraph }

      before do
        git_changes = Faker::Lorem.paragraph
        allow(git_client).to receive(:staged_changes).and_return(git_changes)
        allow(ai_client).to receive(:get_commit_message).with(git_changes).and_return(
          {"subject" => "feat: initial attempt", "description" => "First attempt description"},
          {"subject" => expected_subject, "description" => expected_description}
        )

        allow_any_instance_of(Kernel).to receive(:gets).and_return("R", "Y")
      end

      it "handles the complete commit message workflow", :acceptance do
        expect(git_client).to receive(:commit_all).with(
          {"subject" => expected_subject, "description" => expected_description}
        ).and_return(true)

        expect { suppress_output { Aicommit.run } }.to raise_error(SystemExit)
      end
    end

    context "when not a git repository" do
      it "handles various git repository states gracefully", :acceptance do
        allow(git_client).to receive(:staged_changes).and_raise(
          RuntimeError.new("Not a git repository")
        )

        expect { suppress_output { Aicommit.run } }.to raise_error(RuntimeError, "Not a git repository")
      end
    end
  end

  describe "PR Description Generation" do
    context "when the PR template exists" do
      let(:os_client) { instance_double(Common::OsClient) }

      let(:git_diff) { Faker::Lorem.paragraph }
      let(:pr_description) do
        {
          "title" => Faker::Lorem.word,
          "description" => Faker::Lorem.paragraph
        }
      end

      let(:expected_pr_output_file) { "#{Faker::Lorem.word}.md" }
      let(:expected_base_branch) { Faker::Lorem.word }
      let(:expected_formatted_output) { "# #{pr_description["title"]}\n\n#{pr_description["description"]}" }

      before do
        allow(Common::OsClient).to receive(:new).and_return(os_client)
        allow(os_client).to receive(:host_os).and_return("mswin")

        pr_output_file = instance_double(Common::Envs::PrOutputFile)
        allow(Common::Envs::PrOutputFile).to receive(:new).and_return(pr_output_file)
        allow(pr_output_file).to receive(:fetch).and_return(expected_pr_output_file)

        allow(git_client).to receive(:diff_from_branch_root).with(expected_base_branch).and_return(git_diff)
        allow(ai_client).to receive(:get_pr_description).with(git_diff).and_return(pr_description)
      end

      it "generates PR descriptions with all output options", :acceptance do
        expect(os_client).to receive(:copy_to_clipboard).with(expected_formatted_output)

        file_double = double("file")
        expect(file_double).to receive(:puts).with(expected_formatted_output)
        expect(File).to receive(:open).with(expected_pr_output_file, "w").and_yield(file_double)

        # Test PR generation
        suppress_output {
          Aicommit.generate_pr_description(expected_base_branch, {file: expected_pr_output_file, clipboard: true})
        }
      end
    end
  end
end
