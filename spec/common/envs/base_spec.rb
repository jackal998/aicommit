require "common/envs/base"

# We need a concrete subclass to test the abstract base class
class TestEnv < Common::Envs::Base
  KEY = "TEST_ENV_KEY"

  private

  def get_env_value!
    get_user_input!
  end

  def get_user_input_display_messages
    ["Please enter a test value:"]
  end

  def validate_user_input!(user_input)
    user_input
  end
end

RSpec.describe Common::Envs::Base do
  let(:test_env) { TestEnv.new }
  let(:env_path) { described_class::ENV_PATH }
  let(:env_key) { TestEnv::KEY }
  let(:test_value) { "test_value" }

  before do
    allow(File).to receive(:expand_path).and_return("/fakepath")
    allow(Dotenv).to receive(:load)
    allow(Dotenv).to receive(:overload!)
    allow(File).to receive(:exist?).with(env_path).and_return(false)
    allow(File).to receive(:write)
    allow(test_env).to receive(:puts)
    stub_const("ENV", {})
  end

  describe "#get_env_value!" do
    it "raises NotImplementedError in the base class" do
      expect { described_class.new.send(:get_env_value!) }.to raise_error(NotImplementedError)
    end

    it "works in a concrete subclass" do
      allow(test_env).to receive(:gets).and_return(test_value)
      expect(test_env.send(:get_env_value!)).to eq(test_value)
    end
  end

  describe "#validate_user_input!" do
    it "raises NotImplementedError in the base class" do
      expect { described_class.new.send(:validate_user_input!, "test") }.to raise_error(NotImplementedError)
    end

    it "works in a concrete subclass" do
      expect(test_env.send(:validate_user_input!, test_value)).to eq(test_value)
    end
  end

  describe "#exit_if_quit!" do
    it "exits when input is 'q'" do
      expect { test_env.send(:exit_if_quit!, "q") }.to raise_error(SystemExit)
    end

    it "exits when input is 'Q'" do
      expect { test_env.send(:exit_if_quit!, "Q") }.to raise_error(SystemExit)
    end

    it "doesn't exit for other input" do
      expect { test_env.send(:exit_if_quit!, "not q") }.not_to raise_error
    end
  end

  describe "#updated_env_contents" do
    context "when env file exists" do
      let(:existing_env_content) { "EXISTING_KEY=value\n#{env_key}=old_value\n" }

      before do
        allow(File).to receive(:exist?).with(env_path).and_return(true)
        allow(File).to receive(:read).with(env_path).and_return(existing_env_content)
      end

      it "updates the existing key's value" do
        result = test_env.send(:updated_env_contents, env_key, test_value)
        expect(result).to eq("EXISTING_KEY=value\n#{env_key}=#{test_value}\n")
      end
    end

    context "when env file doesn't exist" do
      it "creates a new env file with the key-value pair" do
        result = test_env.send(:updated_env_contents, env_key, test_value)
        expect(result).to eq("#{env_key}=#{test_value}\n")
      end
    end
  end
end
