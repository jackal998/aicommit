require "pr_description_generator"
require "git_client"

RSpec.describe PrDescriptionGenerator do
  let(:git_client) { instance_double("GitClient") }
  let(:openai_client) { instance_double("OpenAI::Client") }
  let(:base_branch) { "develop" }
  let(:diff) { "sample diff content" }
  let(:pr_description) do
    {
      "title" => "Implement new feature",
      "description" => "## Overview\nThis PR implements a new feature.\n\n## Changes\n- Added feature X\n- Fixed bug Y"
    }
  end

  let(:api_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => pr_description.to_json
          }
        }
      ]
    }
  end

  before do
    allow(GitClient).to receive(:new).and_return(git_client)
    allow(Envs::OpenaiApiKey).to receive_message_chain(:new, :fetch!).and_return("sample_token")
    allow(Envs::SelectedModel).to receive_message_chain(:new, :fetch!).and_return("selected_model")
    allow(Envs::BaseBranch).to receive_message_chain(:new, :fetch!).and_return(base_branch)
    allow(OpenAI::Client).to receive(:new).and_return(openai_client)
    allow(git_client).to receive(:diff_from_branch_root).with(base_branch).and_return(diff)
  end

  describe "#initialize" do
    it "creates a new GitClient and OpenAI client" do
      expect(GitClient).to receive(:new).and_return(git_client)
      expect(OpenAI::Client).to receive(:new).with(access_token: "sample_token").and_return(openai_client)
      subject
    end
  end

  describe "#generate_pr_description" do
    before do
      allow(openai_client).to receive(:chat).and_return(api_response)
      allow(subject).to receive(:set_messages).and_return([{ role: "user", content: "prompt" }])
    end

    it "calls the OpenAI API with the correct parameters" do
      expect(openai_client).to receive(:chat).with(
        parameters: {
          model: anything,
          response_format: { type: "json_object" },
          messages: anything,
          temperature: 0.7
        }
      ).and_return(api_response)

      result = subject.send(:generate_pr_description, diff)
      expect(result).to eq(pr_description)
    end
  end

  describe "#save_pr_description" do
    let(:file) { instance_double(File) }

    before do
      allow(File).to receive(:open).and_yield(file)
      allow(file).to receive(:puts)
    end

    it "writes the PR description to a markdown file" do
      expect(File).to receive(:open).with("PR_DESCRIPTION.md", "w")
      expect(file).to receive(:puts).with("# #{pr_description["title"]}")
      expect(file).to receive(:puts).with("")
      expect(file).to receive(:puts).with(pr_description["description"])

      subject.send(:save_pr_description, pr_description)
    end
  end

  describe "#set_messages" do
    it "creates a message with the prompt and diff content" do
      expect(subject).to receive(:prompt).with(diff).and_return("formatted prompt")
      result = subject.send(:set_messages, diff)
      expect(result).to eq([{ role: "user", content: "formatted prompt" }])
    end

    context "when diff exceeds the limit" do
      let(:long_diff) { "a" * (PrDescriptionGenerator::DIFF_LIMIT + 1000) }

      it "trims the diff and warns the user" do
        expect(subject).to receive(:warn_lengthy_diff)
        expect(subject).to receive(:prompt).with(long_diff[-PrDescriptionGenerator::DIFF_LIMIT..]).and_return("formatted prompt")

        result = subject.send(:set_messages, long_diff)
        expect(result).to eq([{ role: "user", content: "formatted prompt" }])
      end
    end
  end

  describe "#prompt" do
    it "creates a formatted prompt with the diff content" do
      result = subject.send(:prompt, diff)
      expect(result).to include("Instruction:")
      expect(result).to include("Input:\n#{diff}")
      expect(result).to include("Output:")
    end
  end
end
