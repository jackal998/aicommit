require "ignore_file_checker"
require "envs/base"

RSpec.describe IgnoreFileChecker do
  describe "#ensure_env_in_ignore_file" do
    let(:checker) { described_class.new }
    let(:gitignore_path) { ".gitignore" }
    let(:env_path) { Envs::Base::ENV_PATH }
    let(:gitignore_content) { "" }

    before do
      # Setup to avoid touching real file system
      allow(File).to receive(:exist?).and_return(false)
      allow(File).to receive(:exist?).with(gitignore_path).and_return(gitignore_exists)
      allow(File).to receive(:read).with(gitignore_path).and_return(gitignore_content)
      allow(File).to receive(:write)
      allow(STDOUT).to receive(:puts)
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
end
