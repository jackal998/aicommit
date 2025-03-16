require "common/envs/base"
require "common/envs/pr_output_file"

RSpec.describe Common::Envs::PrOutputFile do
  let(:file_path) { "custom/path/pr_desc.md" }
  let(:default_filename) { described_class::DEFAULT_FILENAME }
  let(:env_path) { described_class::ENV_PATH }
  let(:env_key) { described_class::KEY }
  let(:existing_env_content) { "#{env_key}=old_file.md" }

  before do
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
    allow(File).to receive(:write)
    allow(File).to receive(:read).and_return(existing_env_content)
  end

  describe "#fetch" do
    it "returns the existing value from ENV without prompting" do
      stub_const("ENV", env_key => file_path)

      expect(subject.fetch).to eq(file_path)
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
      stub_const("ENV", env_key => file_path)

      expect(subject.fetch!).to eq(file_path)
    end

    it "prompts the user when the value is not set" do
      stub_const("ENV", {})
      expect($stdout).to receive(:puts).with("#{env_key} saved to .env".green)

      expect(subject).to receive(:get_env_value!).and_return(file_path)
      expect(subject.fetch!).to eq(file_path)
    end
  end

  describe "#update!" do
    context "with provided value" do
      before do
        allow(subject).to receive(:validate_filename!).with(file_path).and_return(file_path)
      end

      it "validates and saves the provided filename" do
        expect(subject).to receive(:validate_filename!).with(file_path)
        expect(subject).to receive(:save_to_env!).with(env_key, file_path)
        expect($stdout).to receive(:puts).with("AICOMMIT_PR_OUTPUT_FILE saved to .env".green)
        expect(subject.update!(file_path)).to eq(file_path)
      end
    end

    context "without provided value" do
      before do
        allow(subject).to receive(:get_env_value!).and_return(file_path)
      end

      it "gets the value via get_env_value! and saves it" do
        expect(subject).to receive(:get_env_value!)
        expect(subject).to receive(:save_to_env!).with(env_key, file_path)
        expect($stdout).to receive(:puts).with("AICOMMIT_PR_OUTPUT_FILE saved to .env".green)
        expect(subject.update!).to eq(file_path)
      end
    end
  end

  describe "#get_user_input_display_messages" do
    it "returns the correct messages" do
      messages = subject.send(:get_user_input_display_messages)
      expect(messages).to include(/Enter the default filename or path for PR descriptions/)
      expect(messages).to include(/(Press Enter to use default, or Q to quit)/)
    end
  end

  describe "#validate_filename!" do
    context "with empty input" do
      it "returns the default filename" do
        expect(subject.send(:validate_filename!, "")).to eq(default_filename)
        expect(subject.send(:validate_filename!, "  ")).to eq(default_filename)
        expect(subject.send(:validate_filename!, nil)).to eq(default_filename)
      end
    end

    context "with valid filename" do
      it "returns the provided filename" do
        expect(subject.send(:validate_filename!, "custom.md")).to eq("custom.md")
      end
    end

    context "with path containing directories" do
      let(:dir_path) { "path/to" }
      let(:filename_with_path) { "#{dir_path}/custom.md" }

      context "when directory exists" do
        before do
          allow(Dir).to receive(:exist?).with(dir_path).and_return(true)
        end

        it "returns the full path" do
          expect(subject.send(:validate_filename!, filename_with_path)).to eq(filename_with_path)
        end
      end

      context "when directory doesn't exist" do
        before do
          allow(Dir).to receive(:exist?).with(dir_path).and_return(false)
          allow(FileUtils).to receive(:mkdir_p)
          allow(FileUtils).to receive(:rmdir)
        end

        it "shows a warning and returns the full path in interactive mode" do
          # Simulate being called from validate_user_input!
          allow(subject).to receive(:caller_locations).and_return([OpenStruct.new(label: "validate_user_input!")])
          expect($stdout).to receive(:puts).with(/Warning: Directory .* doesn't exist/).once
          expect(subject.send(:validate_filename!, filename_with_path)).to eq(filename_with_path)
        end

        it "tries to create the directory in non-interactive mode" do
          # Simulate being called from update!
          allow(subject).to receive(:caller_locations).and_return([OpenStruct.new(label: "update!")])
          expect(FileUtils).to receive(:mkdir_p).with(dir_path)
          expect($stdout).to receive(:puts).with(/Created directory/).once
          expect(subject.send(:validate_filename!, filename_with_path)).to eq(filename_with_path)
        end

        it "handles directory creation errors" do
          # Simulate being called from update!
          allow(subject).to receive(:caller_locations).and_return([OpenStruct.new(label: "update!")])
          expect(FileUtils).to receive(:mkdir_p).with(dir_path).and_raise(Errno::EPERM.new("Permission denied"))
          expect($stdout).to receive(:puts).with(/Error: Invalid path/).once
          expect(subject).to receive(:exit).with(1)
          subject.send(:validate_filename!, filename_with_path)
        end
      end
    end

    context "when filename is a directory" do
      before do
        allow(File).to receive(:directory?).with("dir_name").and_return(true)
      end

      it "shows an error and exits in non-interactive mode" do
        # Simulate being called from update!
        allow(subject).to receive(:caller_locations).and_return([OpenStruct.new(label: "update!")])
        expect($stdout).to receive(:puts).with(/Error: .* is a directory, not a file/).once
        expect(subject).to receive(:exit).with(1)
        subject.send(:validate_filename!, "dir_name")
      end

      it "shows an error and prompts again in interactive mode" do
        # Simulate being called from validate_user_input!
        allow(subject).to receive(:caller_locations).and_return([OpenStruct.new(label: "validate_user_input!")])
        expect($stdout).to receive(:puts).with(/Error: .* is a directory, not a file/).once
        expect(subject).to receive(:get_user_input!)
        subject.send(:validate_filename!, "dir_name")
      end
    end
  end

  describe "#get_env_value!" do
    it "calls get_user_input!" do
      expect(subject).to receive(:get_user_input!).and_return("new_file.md")
      expect(subject.send(:get_env_value!)).to eq("new_file.md")
    end
  end

  describe "#validate_user_input!" do
    it "delegates to validate_filename!" do
      expect(subject).to receive(:validate_filename!).with("input.md").and_return("validated.md")
      expect(subject.send(:validate_user_input!, "input.md")).to eq("validated.md")
    end
  end
end
