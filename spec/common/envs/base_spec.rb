require "common/envs/base"
require "colorize"
require "simplecov"

SimpleCov.start

# We need a concrete subclass to test the abstract base class
class TestEnv < Common::Envs::Base
  KEY = "TEST_ENV_KEY"

  private

  def get_env_value!
    get_user_input!
  end

  def get_user_input_display_messages
    ["Enter test value:"]
  end

  def validate_user_input!(user_input)
    raise "Invalid input" if user_input.empty?
    user_input
  end
end

RSpec.describe Common::Envs::Base do
  let(:test_env) { TestEnv.new }
  let(:env_path) { described_class::ENV_PATH }
  let(:env_key) { TestEnv::KEY }
  let(:env_value) { "test_value" }

  before do
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
    allow(File).to receive(:exist?).with(env_path).and_return(false)
    allow(File).to receive(:write)
    allow(test_env).to receive(:puts)
    stub_const("ENV", {})
  end

  describe "#initialize" do
    it "loads environment variables from .env file" do
      expect(Dotenv).to receive(:load).with(env_path)
      TestEnv.new
    end
  end

  describe "#fetch" do
    it "returns the environment variable value" do
      stub_const("ENV", {env_key => env_value})
      expect(test_env.fetch).to eq(env_value)
    end

    it "returns nil if environment variable is not set" do
      stub_const("ENV", {})
      expect(test_env.fetch).to be_nil
    end
  end

  describe "#fetch!" do
    context "when environment variable exists" do
      it "returns the environment variable value" do
        stub_const("ENV", {env_key => env_value})
        expect(test_env.fetch!).to eq(env_value)
      end
    end

    context "when environment variable does not exist" do
      before do
        stub_const("ENV", {})
        allow(test_env).to receive(:update!).and_return(env_value)
      end

      it "calls update! to set the environment variable" do
        expect(test_env).to receive(:update!)
        test_env.fetch!
      end

      it "returns the value from update!" do
        expect(test_env.fetch!).to eq(env_value)
      end
    end
  end

  describe "#update!" do
    context "with provided value" do
      it "saves the provided value to .env" do
        expect(test_env).to receive(:save_to_env!).with(env_key, env_value)
        expect(test_env.update!(env_value)).to eq(env_value)
      end

      it "displays success message with green color" do
        allow(test_env).to receive(:save_to_env!)
        expect(test_env).to receive(:puts).with("#{env_key} saved to .env".green)
        test_env.update!(env_value)
      end
    end

    context "without provided value" do
      before do
        allow(test_env).to receive(:get_env_value!).and_return(env_value)
      end

      it "gets the value via get_env_value! and saves it" do
        expect(test_env).to receive(:get_env_value!)
        expect(test_env).to receive(:save_to_env!).with(env_key, env_value)
        expect(test_env.update!).to eq(env_value)
      end

      it "displays success message with green color" do
        allow(test_env).to receive(:save_to_env!)
        expect(test_env).to receive(:puts).with("#{env_key} saved to .env".green)
        test_env.update!
      end
    end
  end

  describe "#get_env_value!" do
    it "raises NotImplementedError in the base class" do
      base_instance = Common::Envs::Base.new
      expect { base_instance.send(:get_env_value!) }.to raise_error(NotImplementedError)
    end

    it "is implemented in the concrete subclass" do
      allow(test_env).to receive(:get_user_input!).and_return(env_value)
      expect(test_env.send(:get_env_value!)).to eq(env_value)
    end
  end

  describe "#validate_user_input!" do
    it "raises NotImplementedError in the base class" do
      base_instance = Common::Envs::Base.new
      expect { base_instance.send(:validate_user_input!, "input") }.to raise_error(NotImplementedError)
    end

    it "validates input in the concrete subclass" do
      expect(test_env.send(:validate_user_input!, "valid_input")).to eq("valid_input")
    end

    it "raises an error for invalid input in the concrete subclass" do
      expect { test_env.send(:validate_user_input!, "") }.to raise_error("Invalid input")
    end
  end

  describe "#save_to_env!" do
    it "writes the updated content to the .env file" do
      expect(File).to receive(:write).with(env_path, anything)
      expect(Dotenv).to receive(:overload!).with(env_path)
      test_env.send(:save_to_env!, env_key, env_value)
    end
  end

  describe "#updated_env_contents" do
    context "when .env file exists" do
      let(:existing_content) { "EXISTING_KEY=value\n#{env_key}=old_value\nANOTHER_KEY=value2\n" }

      before do
        allow(File).to receive(:exist?).with(env_path).and_return(true)
        allow(File).to receive(:read).with(env_path).and_return(existing_content)
      end

      it "replaces the existing key's value" do
        result = test_env.send(:updated_env_contents, env_key, env_value)
        expect(result).to include("EXISTING_KEY=value")
        expect(result).to include("ANOTHER_KEY=value2")
        expect(result).to include("#{env_key}=#{env_value}")
        expect(result).not_to include("#{env_key}=old_value")
      end
    end

    context "when .env file does not exist" do
      before do
        allow(File).to receive(:exist?).with(env_path).and_return(false)
      end

      it "creates a new content with the key-value pair" do
        result = test_env.send(:updated_env_contents, env_key, env_value)
        expect(result).to eq("#{env_key}=#{env_value}\n")
      end
    end

    context "when .env file exists but the key does not" do
      let(:existing_content) { "EXISTING_KEY=value\nANOTHER_KEY=value2\n" }

      before do
        allow(File).to receive(:exist?).with(env_path).and_return(true)
        allow(File).to receive(:read).with(env_path).and_return(existing_content)
      end

      it "appends the key-value pair to the existing content" do
        result = test_env.send(:updated_env_contents, env_key, env_value)
        expect(result).to include("EXISTING_KEY=value")
        expect(result).to include("ANOTHER_KEY=value2")
        expect(result).to include("#{env_key}=#{env_value}")
      end
    end

    context "when .env file exists but is empty" do
      before do
        allow(File).to receive(:exist?).with(env_path).and_return(true)
        allow(File).to receive(:read).with(env_path).and_return("")
      end

      it "adds the key-value pair to the empty file" do
        result = test_env.send(:updated_env_contents, env_key, env_value)
        expect(result).to eq("#{env_key}=#{env_value}\n")
      end
    end

    context "when .env file content doesn't end with newline" do
      let(:existing_content) { "EXISTING_KEY=value" }

      before do
        allow(File).to receive(:exist?).with(env_path).and_return(true)
        allow(File).to receive(:read).with(env_path).and_return(existing_content)
      end

      it "ensures a newline before adding the new key-value pair" do
        result = test_env.send(:updated_env_contents, env_key, env_value)
        expect(result).to eq("EXISTING_KEY=value\n#{env_key}=#{env_value}\n")
      end
    end
  end

  describe "#get_user_input!" do
    before do
      allow(test_env).to receive(:gets).and_return("user_input\n")
    end

    it "displays input messages to the user" do
      expect(test_env).to receive(:puts).with("Enter test value:")
      test_env.send(:get_user_input!)
    end

    it "returns validated user input" do
      allow(test_env).to receive(:validate_user_input!).and_return("validated_input")
      expect(test_env.send(:get_user_input!)).to eq("validated_input")
    end

    it "exits when user enters 'q'" do
      allow(test_env).to receive(:gets).and_return("q\n")
      expect(test_env).to receive(:exit_if_quit!).with("q").and_call_original
      expect { test_env.send(:get_user_input!) }.to raise_error(SystemExit)
    end

    it "exits when user enters 'Q' (case insensitive)" do
      allow(test_env).to receive(:gets).and_return("Q\n")
      expect(test_env).to receive(:exit_if_quit!).with("Q").and_call_original
      expect { test_env.send(:get_user_input!) }.to raise_error(SystemExit)
    end

    it "strips whitespace from user input" do
      allow(test_env).to receive(:gets).and_return("  user_input  \n")
      allow(test_env).to receive(:validate_user_input!).and_return("user_input")
      expect(test_env.send(:get_user_input!)).to eq("user_input")
    end
  end

  describe "#exit_if_quit!" do
    it "exits when input is 'q'" do
      expect { test_env.send(:exit_if_quit!, "q") }.to raise_error(SystemExit)
    end

    it "exits when input is 'Q'" do
      expect { test_env.send(:exit_if_quit!, "Q") }.to raise_error(SystemExit)
    end

    it "does not exit when input is not 'q'" do
      expect { test_env.send(:exit_if_quit!, "other") }.not_to raise_error
    end

    it "handles nil input without error" do
      expect { test_env.send(:exit_if_quit!, nil) }.not_to raise_error
    end
  end
end
