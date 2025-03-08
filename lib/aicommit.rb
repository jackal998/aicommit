require "openai"
require "json"
require_relative "envs/base"
require_relative "envs/openai_api_token"
require_relative "envs/selected_model"
require_relative "ai_client"
require_relative "git_client"

require "pry"

class Aicommit
  def initialize
  end

  def self.run
    new.run
  end

  def run
    git_diff_str = git_client.git_diff_str
    commit_message = ai_client.get_commit_message(git_diff_str)

    loop do
      puts "Do you want to keep this commit_message? (Y/R/N) (or Q to quit)"
      puts ""
      puts "Commit subject: #{commit_message["subject"]}"
      puts "Description: #{commit_message["description"]}"
      puts ""
      case gets.chomp
      when /^[Yy]$/
        git_client.commit_all(commit_message)
        puts "All changes have been successfully committed."
        exit
      when /^[Rr]$/
        puts "Regenerating..."
        puts ""
        commit_message = ai_client.get_commit_message(git_diff_str)
      when /^[Nn]$/
        puts "Please enter your new commit_message:"
        commit_message = gets.chomp
        puts ""
      when /^[Qq]$/
        puts "Quit without committing."
        exit
      else
        puts "Invalid command. Please enter Y, N, or Q.".underline
        puts ""
      end
    end
  end

  private

  def ai_client
    @_ai_client ||= AiClient.new
  end

  def git_client
    @_git_client ||= GitClient.new
  end
end
