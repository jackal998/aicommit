require "openai"
require "json"
require_relative "envs/base"
require_relative "envs/openai_api_key"
require_relative "envs/selected_model"
require_relative "envs/base_branch"
require_relative "ai_client"
require_relative "git_client"

class Aicommit
  def initialize
    @git_client = GitClient.new
    @ai_client = AiClient.new
  end

  def self.run
    new.run
  end

  def run
    staged_changes = git_client.staged_changes
    commit_message = ai_client.get_commit_message(staged_changes)

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
        commit_message = ai_client.get_commit_message(staged_changes)
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

  attr_reader :git_client, :ai_client
end
