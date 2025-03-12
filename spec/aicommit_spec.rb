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

  describe "#ensure_env_in_ignore_file" do
    let(:ignore_file_checker) { instance_double(Common::Utils::IgnoreFileChecker) }

    it "delegates to Common::Utils::IgnoreFileChecker.ensure_env_in_ignore_file" do
      expect(Common::Utils::IgnoreFileChecker).to receive(:new).and_return(ignore_file_checker)
      expect(ignore_file_checker).to receive(:ensure_env_in_ignore_file)
      described_class.ensure_env_in_ignore_file
    end
  end
end
