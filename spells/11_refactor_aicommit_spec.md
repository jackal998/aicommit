Prompt:
我現在有以下程式：
```ruby
require "git"
require "openai"
require_relative "token_manager"
require_relative "git_client"
require_relative "commit_message_generator"

class Aicommit
  def initialize
    @token_manager = TokenManager.new
  end

  def run
    patch_diffs = git_client.get_patch_str

    commit_message = get_commit_message(patch_diffs)

    loop do
      puts "commit_message: #{commit_message}"
      puts "Do you want to keep this commit_message? (Y/R/N) (or Q to quit)"
      case gets.chomp
      when /^[Yy]$/
        git_client.commit_all(commit_message)
        puts "Committed all changes with message: #{commit_message}"
        exit
      when /^[Rr]$/
        puts "Regenerating..."
        commit_message = get_commit_message(patch_diffs)
      when /^[Nn]$/
        puts "Please enter your new commit_message:"
        commit_message = gets.chomp
      when /^[Qq]$/
        puts "Quit without committing."
        exit
      else
        puts "Invalid command. Please enter Y, N, or Q."
      end
    end
  end

  private

  def get_commit_message(diff)
    response = commit_message_generator.generate(diff)
    if response[:code] == 401
      puts "Invalid API key."
      @token_manager.write!("OPENAI_API_TOKEN")

      get_commit_message(diff)
    else
      response[:result]
    end
  end

  def git_client
    @_git_client ||= GitClient.new
  end

  def commit_message_generator
    @_commit_message_generator ||= CommitMessageGenerator.new(@token_manager.fetch("OPENAI_API_TOKEN"))
  end
end
```
然後我完成了spec的架構，能幫我完成測試嗎？ 我不要使用 `allow_an_instance_of` 這類型的stub， 請幫我使用 `allow(Class).to receive(:new).and_return(instance_double)`這種寫法
```ruby
require "aicommit"

describe Aicommit do
  let(:aicommit) { Aicommit.new }

  describe "#run" do
    it "shows hint commit message and ask user if commit or not" do
    end

    context "when input is Y" do
      it "tells user what commit message would be then commit and exit program" do
      end
    end

    context "when input is R" do
      it "regenerates commit message" do
      end
    end

    context "when input is N" do
      it "allows user to overwrite commit message" do
      end
    end

    context "when input is Q" do
      it "quits without commit" do
      end
    end

    context "when input is not Y, R, N, Q" do
      it "shows warning message and loops again" do
      end
    end
  end
end
```

ChatGPT:
好的，我來幫你完成測試。首先，我們需要將一些物件的實例化改成使用 `instance_double`，這樣才能使用 `allow(Class).to receive(:new).and_return(instance_double)`的寫法。

```ruby
describe Aicommit do
  let(:aicommit) { Aicommit.new }
  let(:git_client) { instance_double(GitClient) }
  let(:commit_message_generator) { instance_double(CommitMessageGenerator) }
  let(:token_manager) { instance_double(TokenManager) }

  before do
    allow(GitClient).to receive(:new).and_return(git_client)
    allow(CommitMessageGenerator).to receive(:new).and_return(commit_message_generator)
    allow(TokenManager).to receive(:new).and_return(token_manager)
    allow(token_manager).to receive(:fetch).with("OPENAI_API_TOKEN").and_return("API_KEY")
  end

  describe "#run" do
    it "shows hint commit message and ask user if commit or not" do
      expect(git_client).to receive(:get_patch_str).and_return("diff")

      expect(commit_message_generator).to receive(:generate).with("diff").and_return({ code: 200, result: "commit message" })

      allow(STDIN).to receive(:gets).and_return("Y\n")
      expect(git_client).to receive(:commit_all).with("commit message")

      expect { aicommit.run }.to output(/commit_message: commit message/).to_stdout
    end

    context "when input is Y" do
      it "tells user what commit message would be then commit and exit program" do
        expect(git_client).to receive(:get_patch_str).and_return("diff")

        expect(commit_message_generator).to receive(:generate).with("diff").and_return({ code: 200, result: "commit message" })

        allow(STDIN).to receive(:gets).and_return("Y\n")
        expect(git_client).to receive(:commit_all).with("commit message")

        expect { aicommit.run }.to output(/Committed all changes with message: commit message/).to_stdout
      end
    end

    context "when input is R" do
      it "regenerates commit message" do
        expect(git_client).to receive(:get_patch_str).and_return("diff")
        expect(commit_message_generator).to receive(:generate).with("diff").and_return({ code: 200, result: "commit message" }, { code: 200, result: "new commit message" })

        allow(STDIN).to receive(:gets).and_return("R\n", "Y\n")
        expect(git_client).to receive(:commit_all).with("new commit message")

        expect { aicommit.run }.to output(/commit_message: new commit message/).to_stdout
      end
    end

    context "when input is N" do
      it "allows user to overwrite commit message" do
        expect(git_client).to receive(:get_patch_str).and_return("diff")
        expect(commit_message_generator).to receive(:generate).with("diff").and_return({ code: 200, result: "commit message" })

        allow(STDIN).to receive(:gets).and_return("N\n", "new commit message\n", "Y\n")
        expect(git_client).to receive(:commit_all).with("new commit message")

        expect { aicommit.run }.to output(/commit_message: new commit message/).to_stdout
      end
    end

    context "when input is Q" do
      it "quits without commit" do
        expect(git_client).to receive(:get_patch_str).and_return("diff")

        allow(STDIN).to receive(:gets).and_return("Q\n")

        expect { aicommit.run }.to output(/Quit without committing/).to_stdout
      end
    end

    context "when input is not Y, R, N, Q" do
      it "shows warning message and loops again" do
        expect(git_client).to receive(:get_patch_str).and_return("diff")

        allow(STDIN).to receive(:gets).and_return("invalid\n", "Y\n")
        expect(commit_message_generator).to receive(:generate).with("diff").and_return({ code: 200, result: "commit message" })
        expect(git_client).to receive(:commit_all).with("commit message")

        expect { aicommit.run }.to output(/Invalid command/).to_stdout
      end
    end
  end
end
```

這樣就完成了，你可以執行 `rspec` 確認所有測試是否通過。
