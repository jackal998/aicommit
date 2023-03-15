require "git"
require "openai"
require_relative "token_manager"
require_relative "git_client"

class Aicommit
  def initialize
    @token_manager = TokenManager.new
  end

  def run
    patch_diffs = git_client.get_patch_str

    commit_message = generate_commit_message(patch_diffs)

    loop do
      puts "commit_message: #{commit_message}"
      puts "Do you want to keep this commit_message? (Y/N) (or Q to quit)"
      command = gets.chomp
      if command.match?(/^[Yy]$/)
        git_client.commit_all(commit_message)
        puts "Committed all changes with message: #{commit_message}"
        break
      elsif command.match?(/^[Nn]$/)
        puts "Please enter your new commit_message:"
        commit_message = gets.chomp
      elsif command.match?(/^[Qq]$/)
        puts "Quit without committing."
        exit
      else
        puts "Invalid command. Please enter Y, N, or Q."
      end
    end
  end

  private

  def generate_commit_message(diff)
    diff = diff[-3800..] || diff
    client = OpenAI::Client.new(access_token: @token_manager.fetch("OPENAI_API_TOKEN"))
    content = "Please generate a commit message based on the following diff in one sentance and less than 80 letters:\n#{diff}"

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [{role: "user", content: content}]
      }
    )

    if response.code == 401
      puts "Invalid API key."
      @token_manager.write!("OPENAI_API_TOKEN")

      return generate_commit_message(diff)
    end

    response.dig("choices", 0, "message", "content").strip
  end

  def git_client
    @_git_client ||= GitClient.new
  end
end
