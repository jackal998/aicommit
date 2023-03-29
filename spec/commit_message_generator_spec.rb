require "commit_message_generator"

RSpec.describe CommitMessageGenerator do
  let(:access_token) { "test_access_token" }
  let(:client) { instance_double(OpenAI::Client) }
  subject { described_class.new(access_token) }

  before do
    allow(OpenAI::Client).to receive(:new).with(access_token: access_token).and_return(client)
  end

  describe "#generate" do
    let(:diff) { "test diff" }
    let(:response) { OpenStruct.new({"choices" => [{"message" => {"content" => "test message"}}], "code" => 200}) }

    it "returns expected format" do
      allow(client).to receive(:chat).and_return(response)

      expect(subject.generate(diff)).to eq({result: "test message", code: 200})
    end

    context "when diff is less than #{described_class::DIFF_LIMIT} chars" do
      let(:diff) { "a" * 1000 }

      it "sends request to OpenAI with all diff" do
        expect(client).to receive(:chat).with(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              {role: "user", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff}"}
            ]
          }
        ).and_return(response)

        subject.generate(diff)
      end
    end

    context "when diff is more than  #{described_class::DIFF_LIMIT} chars" do
      let(:diff) { "a" * 40000 }

      it "sends request to OpenAI with last  #{described_class::DIFF_LIMIT} chars" do
        expect(client).to receive(:chat).with(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              {role: "user", content: "Please generate a commit message based on the following diff in one sentance and less than 80 letters: \n#{diff[-described_class::DIFF_LIMIT..]}"}
            ]
          }
        ).and_return(response)

        expect { subject.generate(diff) }.to output(/Warning: The Git diff is too lengthy \(exceeding the token limit\)./).to_stdout
      end
    end

    context "when API call times out" do
      let(:diff) { "test diff" }

      it "returns an error message" do
        allow(client).to receive(:chat).and_raise(Net::ReadTimeout)

        expect(subject.generate(diff)).to eq({result: "Net::ReadTimeout", code: 500})
      end
    end
  end
end
