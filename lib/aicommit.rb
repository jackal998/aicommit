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
        break
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
    end

    response[:result]
  end

  def git_client
    @_git_client ||= GitClient.new
  end

  def commit_message_generator
    @_commit_message_generator ||= CommitMessageGenerator.new(@token_manager.fetch("OPENAI_API_TOKEN"))
  end
end
