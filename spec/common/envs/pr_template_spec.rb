require "common/envs/base"
require "common/envs/pr_template"

RSpec.describe Common::Envs::PrTemplate do
  let(:template_path) { ".github/pull_request_template.md" }
  let(:env_path) { described_class::ENV_PATH }
  let(:env_key) { described_class::KEY }
  let(:existing_env_content) { "#{env_key}=old_template.md" }
  let(:templates) { [".github/pull_request_template.md", "docs/pull_request_template.md"] }
  let(:custom_path) { "/custom/path/template.md" }

  before do
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
    allow(File).to receive(:write)
    allow(File).to receive(:read).and_return(existing_env_content)
    allow_any_instance_of(described_class).to receive(:find_pr_templates).and_return(templates)
  end

  describe "#initialize" do
    it "initializes with default parameters" do
      expect(described_class.new).to be_a(described_class)
    end

    it "initializes with custom path" do
      instance = described_class.new(custom_path)
      expect(instance.instance_variable_get(:@custom_path)).to eq(custom_path)
    end
  end

  describe "#fetch" do
    it "returns the existing value from ENV without prompting" do
      stub_const("ENV", env_key => template_path)

      expect(subject.fetch).to eq(template_path)
    end

    context "when the value does not exist" do
      it "returns nil" do
        stub_const("ENV", {})

        expect(subject.fetch).to be_nil
      end
    end
  end

  describe "#fetch!" do
    before do
      allow(File).to receive(:write)
    end

    it "returns the existing value without prompting" do
      stub_const("ENV", env_key => template_path)

      expect(subject.fetch!).to eq(template_path)
    end

    it "prompts the user when the value is not set" do
      stub_const("ENV", {})
      allow(subject).to receive(:gets).and_return("1\n")
      allow(subject).to receive(:get_user_input!).and_return("1")
      allow(subject).to receive(:get_env_value!).and_return(templates[0])
      expect(subject).to receive(:puts).with("#{env_key} saved to .env".green)

      expect(subject.fetch!).to eq(templates[0])
    end
  end

  describe "#update!" do
    context "with provided value" do
      before do
        allow(File).to receive(:exist?).with(template_path).and_return(true)
      end

      it "validates and saves the provided template path" do
        expect(subject).to receive(:validate_template_path!).with(template_path)
        expect(subject).to receive(:save_to_env!).with(env_key, template_path)
        expect(subject.update!(template_path)).to eq(template_path)
      end
    end

    context "with custom path" do
      subject { described_class.new(custom_path) }

      before do
        allow(File).to receive(:exist?).with(custom_path).and_return(true)
      end

      it "validates and saves the custom path" do
        expect(subject).to receive(:validate_template_path!).with(custom_path)
        expect(subject).to receive(:save_to_env!).with(env_key, custom_path)
        expect(subject.update!).to eq(custom_path)
      end
    end

    context "without provided value and no custom path" do
      before do
        allow(subject).to receive(:get_env_value!).and_return(template_path)
      end

      it "gets the value via get_env_value! and saves it" do
        expect(subject).to receive(:get_env_value!)
        expect(subject).to receive(:save_to_env!).with(env_key, template_path)
        expect(subject.update!).to eq(template_path)
      end

      it "handles nil value from get_env_value!" do
        allow(subject).to receive(:get_env_value!).and_return(nil)
        expect(subject).not_to receive(:save_to_env!)
        expect(subject).to receive(:puts).with(/No PR template found or selected/)
        expect(subject).to receive(:fetch)
        subject.update!
      end
    end
  end

  describe "#find_pr_templates" do
    before do
      # Unstub the method so we can test the actual implementation
      allow_any_instance_of(described_class).to receive(:find_pr_templates).and_call_original

      # Use actual method implementation but stub file checks
      described_class::TEMPLATE_PATHS[:files].each do |file|
        allow(File).to receive(:exist?).with(file).and_return(false)
      end
      allow(Dir).to receive(:exist?).with(described_class::TEMPLATE_PATHS[:dir]).and_return(false)
    end

    it "returns empty array when no templates are found" do
      expect(subject.find_pr_templates).to eq([])
    end

    it "finds individual template files" do
      template_file = described_class::TEMPLATE_PATHS[:files].first
      allow(File).to receive(:exist?).with(template_file).and_return(true)
      expect(subject.find_pr_templates).to eq([template_file])
    end

    it "finds templates in the template directory" do
      template_dir = described_class::TEMPLATE_PATHS[:dir]
      template_files = ["#{template_dir}/pr1.md", "#{template_dir}/pr2.md"]

      allow(Dir).to receive(:exist?).with(template_dir).and_return(true)
      allow(Dir).to receive(:glob).with("#{template_dir}/*.md").and_return(template_files)

      expect(subject.find_pr_templates).to eq(template_files)
    end

    it "collects both individual files and directory templates" do
      template_file = described_class::TEMPLATE_PATHS[:files].first
      template_dir = described_class::TEMPLATE_PATHS[:dir]
      template_files = ["#{template_dir}/pr1.md", "#{template_dir}/pr2.md"]

      allow(File).to receive(:exist?).with(template_file).and_return(true)
      allow(Dir).to receive(:exist?).with(template_dir).and_return(true)
      allow(Dir).to receive(:glob).with("#{template_dir}/*.md").and_return(template_files)

      expect(subject.find_pr_templates).to eq([template_file] + template_files)
    end
  end

  describe "#validate_template_selection" do
    let(:templates) { ["template1.md", "template2.md", "template3.md"] }

    it "returns true for valid selection" do
      expect(subject.validate_template_selection(1, templates)).to be true
      expect(subject.validate_template_selection(2, templates)).to be true
      expect(subject.validate_template_selection(3, templates)).to be true
    end

    it "returns false for invalid selection" do
      expect(subject).to receive(:puts).with(/Invalid selection/).once
      expect(subject.validate_template_selection(0, templates)).to be false

      expect(subject).to receive(:puts).with(/Invalid selection/).once
      expect(subject.validate_template_selection(4, templates)).to be false

      expect(subject).to receive(:puts).with(/Invalid selection/).once
      expect(subject.validate_template_selection(-1, templates)).to be false
    end
  end

  describe "#get_env_value!" do
    context "with custom path specified in constructor" do
      subject { described_class.new(custom_path) }

      it "returns the custom path if it exists" do
        allow(File).to receive(:exist?).with(custom_path).and_return(true)
        expect(subject.send(:get_env_value!)).to eq(custom_path)
      end

      it "raises an error if the custom path doesn't exist" do
        allow(File).to receive(:exist?).with(custom_path).and_return(false)
        expect(subject).to receive(:puts).with("Specified template file '#{custom_path}' not found.".red)

        expect { subject.send(:get_env_value!) }.to raise_error(SystemExit)
      end
    end

    context "with no custom path" do
      before do
        allow(subject).to receive(:gets).and_return("1\n")
      end

      it "returns the selected template when templates are found" do
        templates = ["template1.md", "template2.md"]
        allow(subject).to receive(:find_pr_templates).and_return(templates)
        expect(subject.send(:get_env_value!)).to eq(templates[0])
      end

      it "returns nil when no templates are found" do
        allow(subject).to receive(:find_pr_templates).and_return([])
        expect(subject).to receive(:puts).with(/No PR templates found/)
        expect(subject.send(:get_env_value!)).to be_nil
      end
    end
  end

  describe "#get_user_input_display_messages" do
    it "returns the correct messages" do
      templates = ["template1.md", "template2.md"]
      allow(subject).to receive(:find_pr_templates).and_return(templates)

      messages = subject.send(:get_user_input_display_messages)
      expect(messages.first).to include("Please select a PR template")
      expect(messages).to include("1. template1.md")
      expect(messages).to include("2. template2.md")
    end
  end

  describe "#validate_user_input!" do
    before do
      allow(subject).to receive(:find_pr_templates).and_return(["template1.md", "template2.md"])
    end

    it "returns the input for valid selection" do
      expect(subject.send(:validate_user_input!, "1")).to eq("1")
      expect(subject.send(:validate_user_input!, "2")).to eq("2")
    end

    it "exits for invalid selection" do
      expect(subject).to receive(:puts).with(/Invalid selection/)
      expect(subject).to receive(:exit)
      subject.send(:validate_user_input!, "3")
    end
  end

  describe "#validate_template_path!" do
    it "returns the path if it exists" do
      allow(File).to receive(:exist?).with(template_path).and_return(true)
      expect(subject.send(:validate_template_path!, template_path)).to eq(template_path)
    end

    it "returns nil if the path is nil" do
      expect(subject.send(:validate_template_path!, nil)).to be_nil
    end

    it "raises an error if the path doesn't exist" do
      allow(File).to receive(:exist?).with(template_path).and_return(false)
      expect(subject).to receive(:puts).with(/Error: Template file .* not found/).once
      expect(subject).to receive(:exit).with(1)
      subject.send(:validate_template_path!, template_path)
    end
  end

  describe "#get_template_content" do
    it "returns the content if the template exists" do
      content = "# Template Content"
      allow(File).to receive(:exist?).with(template_path).and_return(true)
      allow(File).to receive(:read).with(template_path).and_return(content)
      expect(subject.send(:get_template_content, template_path)).to eq(content)
    end

    it "returns nil if the template doesn't exist" do
      allow(File).to receive(:exist?).with(template_path).and_return(false)
      expect(subject.send(:get_template_content, template_path)).to be_nil
    end

    it "returns nil if the template path is nil" do
      expect(subject.send(:get_template_content, nil)).to be_nil
    end
  end
end
