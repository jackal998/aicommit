require "common/utils/ignore_file_checker"
require "common/envs/base"

RSpec.describe Common::Utils::IgnoreFileChecker do
  describe "#ensure_env_in_ignore_file" do
    let(:checker) { described_class.new }
    let(:gitignore_path) { ".gitignore" }
    let(:env_path) { Common::Envs::Base::ENV_PATH }
    let(:gitignore_content) { "" }

    before do
      # Setup to avoid touching real file system
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:exist?).with(gitignore_path).and_return(gitignore_exists)
      allow(File).to receive(:read).with(gitignore_path).and_return(gitignore_content)
      allow(File).to receive(:write)
      allow($stdout).to receive(:puts)
    end

    context "when .gitignore doesn't exist" do
      let(:gitignore_exists) { false }

      it "doesn't modify anything" do
        expect(File).not_to receive(:write)
        checker.ensure_env_in_ignore_file
      end
    end

    context "when .gitignore exists but doesn't contain .env" do
      let(:gitignore_exists) { true }
      let(:gitignore_content) { "# Some other content\n*.log\nnode_modules/\n" }

      it "appends .env to the file" do
        expected_content = "# Some other content\n*.log\nnode_modules/\n\n# Environment variables\n#{env_path}\n"
        expect(File).to receive(:write).with(gitignore_path, expected_content)
        checker.ensure_env_in_ignore_file
      end
    end

    context "when .gitignore contains .env on its own line" do
      let(:gitignore_exists) { true }
      let(:gitignore_content) { "# Some other content\n#{env_path}\n*.log\n" }

      it "doesn't modify the file" do
        expect(File).not_to receive(:write).with(gitignore_path, anything)
        checker.ensure_env_in_ignore_file
      end
    end

    context "when .gitignore contains a line starting with .env" do
      let(:gitignore_exists) { true }
      let(:gitignore_content) { "# Some other content\n#{env_path}_extra\n*.log\n" }

      it "doesn't modify the file because the line starts with .env" do
        expect(File).not_to receive(:write).with(gitignore_path, anything)
        checker.ensure_env_in_ignore_file
      end
    end

    context "when .gitignore contains multiple entries including .env" do
      let(:gitignore_exists) { true }
      let(:gitignore_content) { "*.log\n#{env_path}\nnode_modules/\n" }

      it "doesn't modify the file" do
        expect(File).not_to receive(:write).with(gitignore_path, anything)
        checker.ensure_env_in_ignore_file
      end
    end

    context "when .gitignore contains .env with spacing" do
      let(:gitignore_exists) { true }
      let(:gitignore_content) { "*.log\n  #{env_path}  \nnode_modules/\n" }

      it "doesn't modify the file" do
        expect(File).not_to receive(:write).with(gitignore_path, anything)
        checker.ensure_env_in_ignore_file
      end
    end

    context "when .gitignore has other env-like entries but not .env exactly" do
      let(:gitignore_exists) { true }
      let(:gitignore_content) { "*.log\n.env.local\n.env.development\nnode_modules/\n" }

      it "doesn't modify the file" do
        expect(File).not_to receive(:write).with(gitignore_path, anything)
        checker.ensure_env_in_ignore_file
      end
    end
  end

  describe "#parsed_ignore_file_content" do
    let(:checker) { described_class.new }
    let(:content) { "line1\nline2\n\nline3" }

    it "parses gitignore content correctly" do
      result = checker.send(:parsed_ignore_file_content, ".gitignore", content)
      expect(result).to eq(["line1", "line2", "line3"])
    end

    it "raises an error for unknown ignore file types" do
      expect { checker.send(:parsed_ignore_file_content, "unknown_file", content) }
        .to raise_error(RuntimeError, "Unknown ignore file path: unknown_file")
    end
  end

  describe "#append_env_to_ignore_file" do
    let(:checker) { described_class.new }
    let(:content) { "existing content" }
    let(:env_path) { Common::Envs::Base::ENV_PATH }

    before do
      allow(File).to receive(:write)
      allow($stdout).to receive(:puts)
    end

    it "appends env path to gitignore correctly" do
      expected_content = "existing content\n\n# Environment variables\n#{env_path}\n"
      expect(File).to receive(:write).with(".gitignore", expected_content)
      checker.send(:append_env_to_ignore_file, ".gitignore", content)
    end

    it "raises an error for unknown ignore file types" do
      expect { checker.send(:append_env_to_ignore_file, "unknown_file", content) }
        .to raise_error(RuntimeError, "Unknown ignore file path: unknown_file")
    end
  end
end
