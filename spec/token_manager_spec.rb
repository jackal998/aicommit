require "dotenv"
require "token_manager"

RSpec.describe TokenManager do
  before { allow(subject).to receive(:puts) }
  after { File.delete(TokenManager::ENV_PATH) if File.file?(TokenManager::ENV_PATH) }

  describe "#fetch" do
    context "when required token not present" do
      it "asks for user's input, save to .env file and returns user's input" do
        expect(subject).to receive(:gets).and_return("test_token")
        expect(subject.fetch("TEST_TOKEN")).to eq("test_token")
        expect(File.read(TokenManager::ENV_PATH)).to include("TEST_TOKEN=test_token")
      end
    end

    context "when required token present" do
      before do
        ENV["EXISTING_TOKEN"] = "existing_token"
      end

      it "returns token" do
        expect(subject.fetch("EXISTING_TOKEN")).to eq("existing_token")
      end
    end
  end

  describe "#write!" do
    it "asks for user's input, save to .env file and returns user's input" do
      expect(subject).to receive(:gets).and_return("test_token")
      expect(subject.write!("TEST_TOKEN")).to eq("test_token")
      expect(File.read(TokenManager::ENV_PATH)).to include("TEST_TOKEN=test_token")
    end
  end
end
