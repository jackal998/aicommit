require "spec_helper"
require_relative "../../lib/common/os_client"

RSpec.describe Common::OsClient do
  let(:os_client) { described_class.new }

  describe "#copy_to_clipboard" do
    let(:content) { "Test content" }

    context "on macOS" do
      before do
        allow(os_client).to receive(:host_os).and_return("darwin")
      end

      it "uses pbcopy command" do
        io_double = double("io")
        expect(IO).to receive(:popen).with("pbcopy", "w").and_yield(io_double)
        expect(io_double).to receive(:<<).with(content)
        os_client.copy_to_clipboard(content)
      end
    end

    context "on Linux" do
      before do
        allow(os_client).to receive(:host_os).and_return("linux")
      end

      it "uses xclip command" do
        io_double = double("io")
        expect(IO).to receive(:popen).with("xclip -selection clipboard", "w").and_yield(io_double)
        expect(io_double).to receive(:<<).with(content)
        os_client.copy_to_clipboard(content)
      end
    end

    context "on Windows" do
      before do
        allow(os_client).to receive(:host_os).and_return("mswin")
      end

      it "uses clip command" do
        io_double = double("io")
        expect(IO).to receive(:popen).with("clip", "w").and_yield(io_double)
        expect(io_double).to receive(:<<).with(content)
        os_client.copy_to_clipboard(content)
      end
    end

    context "on MinGW" do
      before do
        allow(os_client).to receive(:host_os).and_return("mingw")
      end

      it "uses clip command" do
        io_double = double("io")
        expect(IO).to receive(:popen).with("clip", "w").and_yield(io_double)
        expect(io_double).to receive(:<<).with(content)
        os_client.copy_to_clipboard(content)
      end
    end

    context "on unsupported OS" do
      before do
        allow(os_client).to receive(:host_os).and_return("unknown_os")
      end

      it "shows a warning message" do
        expect { os_client.copy_to_clipboard(content) }.to output(/Warning: Clipboard functionality not supported/).to_stdout
      end
    end
  end
end
