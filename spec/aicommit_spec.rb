require "aicommit"
require "commit/generator"

describe Aicommit do
  describe "#run" do
    it "delegates to Commit::Generator.run" do
      expect(Commit::Generator).to receive(:run)
      described_class.run
    end
  end

  describe "#generate_pr_description" do
    let(:base_ref) { "main" }
    let(:options) { {clipboard: true} }
    let(:generator_instance) { instance_double(PR::Generator) }

    it "delegates to PR::Generator" do
      expect(PR::Generator).to receive(:new).with(base_ref, options).and_return(generator_instance)
      expect(generator_instance).to receive(:run)
      described_class.generate_pr_description(base_ref, options)
    end
  end

  describe "#set_openai_api_key" do
    let(:openai_api_key) { instance_double(Common::Envs::OpenaiApiKey) }

    it "delegates to Common::Envs::OpenaiApiKey.update!" do
      expect(Common::Envs::OpenaiApiKey).to receive(:new).and_return(openai_api_key)
      expect(openai_api_key).to receive(:update!)
      described_class.set_openai_api_key
    end
  end

  describe "#set_selected_model" do
    let(:selected_model) { instance_double(Common::Envs::SelectedModel) }

    it "delegates to Common::Envs::SelectedModel.update!" do
      expect(Common::Envs::SelectedModel).to receive(:new).and_return(selected_model)
      expect(selected_model).to receive(:update!)
      described_class.set_selected_model
    end
  end

  describe "#set_base_branch" do
    let(:base_branch) { instance_double(Common::Envs::BaseBranch) }

    it "delegates to Common::Envs::BaseBranch.update!" do
      expect(Common::Envs::BaseBranch).to receive(:new).and_return(base_branch)
      expect(base_branch).to receive(:update!)
      described_class.set_base_branch
    end
  end

  describe "#set_pr_template" do
    let(:pr_template) { instance_double(Common::Envs::PrTemplate) }
    let(:custom_path) { "custom_template.md" }

    it "delegates to Common::Envs::PrTemplate.update!" do
      expect(Common::Envs::PrTemplate).to receive(:new).with(custom_path).and_return(pr_template)
      expect(pr_template).to receive(:update!)
      described_class.set_pr_template(custom_path)
    end

    it "works without a custom path" do
      expect(Common::Envs::PrTemplate).to receive(:new).with(nil).and_return(pr_template)
      expect(pr_template).to receive(:update!)
      described_class.set_pr_template
    end
  end

  describe "#set_pr_output_file" do
    let(:pr_output_file) { instance_double(Common::Envs::PrOutputFile) }
    let(:filename) { "custom_output.md" }

    it "delegates to Common::Envs::PrOutputFile.update!" do
      expect(Common::Envs::PrOutputFile).to receive(:new).and_return(pr_output_file)
      expect(pr_output_file).to receive(:update!).with(filename)
      described_class.set_pr_output_file(filename)
    end

    it "works without a filename" do
      expect(Common::Envs::PrOutputFile).to receive(:new).and_return(pr_output_file)
      expect(pr_output_file).to receive(:update!).with(nil)
      described_class.set_pr_output_file
    end
  end

  describe "#show_config" do
    let(:api_key) { "sk-abcdefghijklmnopqrstuvwxyz1234" }
    let(:model) { "gpt-4" }
    let(:branch) { "main" }
    let(:template) { "template.md" }
    let(:output_file) { "output.md" }

    before do
      allow_any_instance_of(Common::Envs::OpenaiApiKey).to receive(:fetch).and_return(api_key)
      allow_any_instance_of(Common::Envs::SelectedModel).to receive(:fetch).and_return(model)
      allow_any_instance_of(Common::Envs::BaseBranch).to receive(:fetch).and_return(branch)
      allow_any_instance_of(Common::Envs::PrTemplate).to receive(:fetch).and_return(template)
      allow_any_instance_of(Common::Envs::PrOutputFile).to receive(:fetch).and_return(output_file)
    end

    it "outputs the current configuration" do
      expect { described_class.show_config }.to output(/Current Configuration/).to_stdout
      expect { described_class.show_config }.to output(/OpenAI API Key: sk-...1234/).to_stdout
      expect { described_class.show_config }.to output(/Selected Model: #{model}/).to_stdout
      expect { described_class.show_config }.to output(/Base Branch: #{branch}/).to_stdout
      expect { described_class.show_config }.to output(/PR Template: #{template}/).to_stdout
      expect { described_class.show_config }.to output(/PR Output File: #{output_file}/).to_stdout
    end

    it "handles missing configuration values" do
      allow_any_instance_of(Common::Envs::OpenaiApiKey).to receive(:fetch).and_return(nil)
      allow_any_instance_of(Common::Envs::SelectedModel).to receive(:fetch).and_return(nil)

      expect { described_class.show_config }.to output(/OpenAI API Key: Not set/).to_stdout
      expect { described_class.show_config }.to output(/Selected Model: Not set/).to_stdout
    end
  end

  describe "#handle_error" do
    it "handles OpenAI API authentication errors" do
      error = OpenAI::Error.new("Incorrect API key provided")
      expect { described_class.handle_error(error) }.to output(/Invalid API key/).to_stdout
                                                    .and raise_error(SystemExit)
    end

    it "handles OpenAI API rate limit errors" do
      error = OpenAI::Error.new("Rate limit exceeded")
      expect { described_class.handle_error(error) }.to output(/Rate limit exceeded/).to_stdout
                                                    .and raise_error(SystemExit)
    end

    it "handles OpenAI API network errors" do
      error = OpenAI::Error.new("Network error")
      expect { described_class.handle_error(error) }.to output(/Network Error/).to_stdout
                                                    .and raise_error(SystemExit)
    end

    it "handles generic OpenAI API errors" do
      error = OpenAI::Error.new("Some other error")
      expect { described_class.handle_error(error) }.to output(/OpenAI API Error: Some other error/).to_stdout
                                                    .and raise_error(SystemExit)
    end

    it "handles non-OpenAI errors" do
      error = StandardError.new("Generic error")
      expect { described_class.handle_error(error) }.to output(/Error: Generic error/).to_stdout
                                                    .and raise_error(SystemExit)
    end
  end

  describe "#ensure_env_in_ignore_file" do
    let(:ignore_file_checker) { instance_double(Common::Utils::IgnoreFileChecker) }

    it "delegates to Common::Utils::IgnoreFileChecker.ensure_env_in_ignore_file" do
      expect(Common::Utils::IgnoreFileChecker).to receive(:new).and_return(ignore_file_checker)
      expect(ignore_file_checker).to receive(:ensure_env_in_ignore_file)
      described_class.ensure_env_in_ignore_file
    end
  end
end
