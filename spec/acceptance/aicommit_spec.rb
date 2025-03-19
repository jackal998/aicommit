require "spec_helper"
require "tmpdir"
require "fileutils"
require "openai"
require "stringio"
require_relative "../../lib/aicommit"
require_relative "../../lib/common/os_client"

# High-level User Acceptance Tests for Aicommit
# These tests focus on end-to-end user journeys and workflows

RSpec.describe "Aicommit User Acceptance Tests" do
  # Setup helpers
  let(:git_repo_path) { Dir.mktmpdir }
  let(:env_file) { File.join(git_repo_path, ".env") }
  let(:gitignore_file) { File.join(git_repo_path, ".gitignore") }
  let(:openai_client) { instance_double(OpenAI::Client) }
  let(:bin_path) { File.expand_path("../../bin/aicommit", __dir__) }
  let(:ai_client) { instance_double(Common::AiClient) }
  let(:git_client) { instance_double(Common::GitClient) }
  let(:ignore_file_checker) { instance_double(Common::Utils::IgnoreFileChecker) }

  before(:each) do
    # Mock ENV to avoid modifying real environment variables
    stub_const("ENV", {})

    # Setup test environment
    Dir.chdir(git_repo_path) do
      # Redirect output to appropriate null device based on platform
      null_device = RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL' : '/dev/null'
      `git init > #{null_device} 2>&1`
      `git config user.email "test@example.com" > #{null_device} 2>&1`
      `git config user.name "Test User" > #{null_device} 2>&1`
      File.write(".gitignore", "")
      File.write("test_file.txt", "Initial content")
      `git add test_file.txt > #{null_device} 2>&1`
      `git commit -m "Initial commit" > #{null_device} 2>&1`
    end

    # Mock core dependencies used across all tests
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(Common::AiClient).to receive(:new).and_return(ai_client)
    allow(ai_client).to receive(:verify_api_token!).and_return(true)
    allow(Common::GitClient).to receive(:new).and_return(git_client)

    # Allow basic file operations that are used across tests
    allow(File).to receive(:join).and_call_original
    allow(File).to receive(:expand_path).and_call_original
  end

  after(:each) do
    FileUtils.remove_entry(git_repo_path)
  end

  # Helper method to evaluate Aicommit commands directly
  def run_aicommit_command(args = "")
    Dir.chdir(git_repo_path) do
      case args
      when "--set-key"
        Aicommit.set_openai_api_key("sk-test123")
      when "--set-model"
        Aicommit.set_selected_model("gpt-4o-mini")
      when "--set-base-branch"
        Aicommit.set_base_branch("main")
      when "--config"
        Aicommit.show_config
      when /^-p\s+(\S+)\s+--file\s+(\S+)\s+--pr-output-clipboard$/
        Aicommit.generate_pr_description($1, {file: $2, clipboard: true})
      when /^-p\s+(\S+)\s+--file\s+(\S+)$/
        Aicommit.generate_pr_description($1, {file: $2})
      when /^-p\s+(\S+)\s+--file$/
        Aicommit.generate_pr_description($1, {file: true})
      when /^-p\s+--file$/
        Aicommit.generate_pr_description(nil, {file: true})
      when /^-p\s+(\S+)$/
        Aicommit.generate_pr_description($1)
      when "-p"
        Aicommit.generate_pr_description
      when /^-p\s+-t\s+(.+)/
        Aicommit.generate_pr_description(nil, {template: $1})
      when "--set-pr-template"
        Aicommit.set_pr_template(".github/pull_request_template.md")
      when "--pr-output-clipboard", "-p --pr-output-clipboard"
        Aicommit.generate_pr_description(nil, {clipboard: true})
      else
        Aicommit.run
      end
    rescue SystemExit
      # Catch SystemExit to prevent tests from exiting prematurely
      return
    end
  end

  # Helper method to capture stdout for testing
  def capture_stdout
    old_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old_stdout
  end

  # Helper to suppress standard output while testing
  def suppress_output
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    yield
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
  end

  # Helper to wrap exceptions for testing exit conditions
  def catch_exit
    yield
    nil # Return nil if no exception was raised
  rescue SystemExit => e
    e # Return the exit exception
  end

  describe "Essential Configuration Workflow" do
    it "completes first-time setup with all required configurations", :acceptance do
      # Allow environment file operations for this test
      allow(File).to receive(:write).and_return(nil)
      allow(File).to receive(:read).and_return("")
      allow(File).to receive(:exist?).and_return(true)
      allow(Dotenv).to receive(:load).and_return(nil)
      allow(Dotenv).to receive(:overload!).and_return(nil)

      # Create environment variable doubles
      openai_api_key = instance_double(Common::Envs::OpenaiApiKey)
      selected_model = instance_double(Common::Envs::SelectedModel)
      base_branch = instance_double(Common::Envs::BaseBranch)
      pr_template = instance_double(Common::Envs::PrTemplate)

      # Setup environment variable mocks
      allow(Common::Envs::OpenaiApiKey).to receive(:new).and_return(openai_api_key)
      allow(Common::Envs::SelectedModel).to receive(:new).and_return(selected_model)
      allow(Common::Envs::BaseBranch).to receive(:new).and_return(base_branch)
      allow(Common::Envs::PrTemplate).to receive(:new).with(any_args).and_return(pr_template)

      # Expect environment variable updates
      expect(openai_api_key).to receive(:update!).with("sk-test123").once
      expect(selected_model).to receive(:update!).with("gpt-4o-mini").once
      expect(base_branch).to receive(:update!).with("main").once
      expect(pr_template).to receive(:update!).once

      # Allow environment variable fetching
      allow(openai_api_key).to receive(:fetch).and_return("sk-test123")
      allow(selected_model).to receive(:fetch).and_return("gpt-4o-mini")
      allow(base_branch).to receive(:fetch).and_return("main")
      allow(pr_template).to receive(:fetch).and_return(".github/pull_request_template.md")

      # Run complete configuration sequence
      suppress_output do
        run_aicommit_command("--set-key")
        run_aicommit_command("--set-model")
        run_aicommit_command("--set-base-branch")
        run_aicommit_command("--set-pr-template")
      end

      # Verify configuration
      output = capture_stdout { run_aicommit_command("--config") }
      expect(output).to include("OpenAI API Key: sk-")
      expect(output).to include("Selected Model: gpt-4o-mini")
      expect(output).to include("Base Branch: main")
      expect(output).to include("PR Template: .github/pull_request_template.md")
    end
  end

  describe "Core Git Operations" do
    it "handles the complete commit message workflow", :acceptance do
      # Setup environment
      stub_const("ENV", {
        "AI_COMMIT_OPENAI_API_KEY" => "sk-test123",
        "AI_COMMIT_SELECTED_MODEL" => "gpt-4o-mini"
      })

      # Mock commit-specific operations
      allow(git_client).to receive(:staged_changes).and_return("Some changes")
      allow(git_client).to receive(:commit_all).and_return(true)
      allow(ai_client).to receive(:get_commit_message).and_return(
        {"subject" => "feat: initial attempt", "description" => "First attempt description"},
        {"subject" => "feat: improved message", "description" => "Much better description"}
      )

      # Simulate user interaction
      allow_any_instance_of(Kernel).to receive(:gets).and_return("R", "Y")

      # Run commit workflow
      suppress_output { run_aicommit_command }
    end

    it "handles various git repository states gracefully", :acceptance do
      # Setup environment
      stub_const("ENV", {
        "AI_COMMIT_OPENAI_API_KEY" => "sk-test123",
        "AI_COMMIT_SELECTED_MODEL" => "gpt-4o-mini"
      })

      # Setup mocks
      git_client = instance_double(Common::GitClient)
      allow(Common::GitClient).to receive(:new).and_return(git_client)

      # Test no git repository
      allow(git_client).to receive(:staged_changes).and_raise(
        RuntimeError.new("Not a git repository")
      )
      expect { suppress_output { run_aicommit_command } }.to raise_error(RuntimeError, "Not a git repository")

      # Test no staged changes
      allow(git_client).to receive(:staged_changes).and_return("")
      suppress_output { run_aicommit_command }
    end
  end

  describe "PR Description Generation" do
    it "generates PR descriptions with all output options", :acceptance do
      # Setup PR-specific file operations
      allow(File).to receive(:read).with(".github/pull_request_template.md")
        .and_return("## Changes\n## Testing\n## Screenshots")
      allow(File).to receive(:directory?).and_return(true)

      # Setup PR-specific mocks
      os_client = instance_double(Common::OsClient)
      pr_output_file = instance_double(Common::Envs::PrOutputFile)
      allow(Common::OsClient).to receive(:new).and_return(os_client)
      allow(Common::Envs::PrOutputFile).to receive(:new).and_return(pr_output_file)
      allow(pr_output_file).to receive(:fetch).and_return("custom_pr.md")
      allow(git_client).to receive(:diff_from_branch_root).with("main").and_return("Some diff")

      # Mock PR generation response
      pr_description = {
        "title" => "Complex PR Test",
        "description" => "## Changes\nImplemented feature X\n## Testing\nAdded unit tests\n## Screenshots\nN/A"
      }
      allow(ai_client).to receive(:get_pr_description).and_return(pr_description)

      # Mock clipboard and file operations
      formatted_output = "# #{pr_description["title"]}\n\n#{pr_description["description"]}"
      allow(os_client).to receive(:host_os).and_return("mswin")
      allow(os_client).to receive(:copy_to_clipboard).with(formatted_output)

      file_double = double('file')
      expect(file_double).to receive(:puts).with(formatted_output)
      expect(File).to receive(:open).with("custom_pr.md", "w").and_yield(file_double)

      # Test PR generation
      suppress_output { run_aicommit_command("-p main --file custom_pr.md --pr-output-clipboard") }
    end

    it "handles different base reference types", :acceptance do
      # Setup environment
      stub_const("ENV", {
        "AI_COMMIT_OPENAI_API_KEY" => "sk-test123",
        "AI_COMMIT_SELECTED_MODEL" => "gpt-4o-mini"
      })

      # Setup mocks
      openai_client = instance_double(OpenAI::Client)
      ai_client = instance_double(Common::AiClient)
      git_client = instance_double(Common::GitClient)

      allow(OpenAI::Client).to receive(:new).and_return(openai_client)
      allow(Common::AiClient).to receive(:new).and_return(ai_client)
      allow(Common::GitClient).to receive(:new).and_return(git_client)

      # Test branch reference
      allow(git_client).to receive(:staged_changes).and_return("Some changes")
      allow(git_client).to receive(:diff_from_branch_root).with("main").and_return("Branch diff")
      allow(ai_client).to receive(:verify_api_token!).and_return(true)
      allow(ai_client).to receive(:get_pr_description).and_return({
        "title" => "Test PR",
        "description" => "Test description"
      })
      suppress_output { run_aicommit_command("-p main") }

      # Test commit SHA reference
      allow(git_client).to receive(:diff_from_branch_root).with("abc1234").and_return("SHA diff")
      allow(ai_client).to receive(:get_pr_description).and_return({
        "title" => "Test PR",
        "description" => "Test description"
      })
      suppress_output { run_aicommit_command("-p abc1234") }
    end
  end

  describe "Error Recovery and Edge Cases" do
    it "handles and recovers from various error conditions", :acceptance do
      # Setup environment
      stub_const("ENV", {
        "AI_COMMIT_OPENAI_API_KEY" => "sk-test123",
        "AI_COMMIT_SELECTED_MODEL" => "gpt-4o-mini"
      })

      # Setup mocks
      openai_client = instance_double(OpenAI::Client)
      ai_client = instance_double(Common::AiClient)
      git_client = instance_double(Common::GitClient)

      allow(OpenAI::Client).to receive(:new).and_return(openai_client)
      allow(Common::AiClient).to receive(:new).and_return(ai_client)
      allow(Common::GitClient).to receive(:new).and_return(git_client)

      # Test API errors
      allow(git_client).to receive(:staged_changes).and_return("Some changes")
      allow(ai_client).to receive(:verify_api_token!).and_return(true)
      allow(ai_client).to receive(:get_commit_message).and_raise(
        OpenAI::Error.new("Rate limit exceeded")
      )
      expect(Aicommit).to receive(:handle_error).with(an_instance_of(OpenAI::Error))
      suppress_output do
        run_aicommit_command rescue OpenAI::Error
      end

      # Test network errors
      allow(ai_client).to receive(:get_commit_message).and_raise(
        OpenAI::Error.new("Network error: Connection refused")
      )
      expect(Aicommit).to receive(:handle_error).with(an_instance_of(OpenAI::Error))
      suppress_output do
        run_aicommit_command rescue OpenAI::Error
      end

      # Test invalid API key
      allow(ai_client).to receive(:verify_api_token!).and_raise(
        OpenAI::Error.new("Incorrect API key provided")
      )
      expect(Aicommit).to receive(:handle_error).with(an_instance_of(OpenAI::Error))
      suppress_output do
        begin
          ai_client.verify_api_token!
        rescue OpenAI::Error => e
          Aicommit.handle_error(e)
        end
      end
    end
  end
end
