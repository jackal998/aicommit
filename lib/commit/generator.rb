require "openai"
require "json"
require_relative "../common/envs/openai_api_key"
require_relative "../common/envs/selected_model"
require_relative "../common/ai_client"
require_relative "../common/git_client"

module Commit
  class Generator
    def initialize
      @git_client = Common::GitClient.new
      @ai_client = Common::AiClient.new
    end

    def self.run
      new.run
    end

    def run
      staged_changes = git_client.staged_changes
      
      if staged_changes.strip.empty?
        puts "No staged changes found. Please stage changes using 'git add' before running aicommit.".red
        exit 1
      end
      
      commit_message = ai_client.get_commit_message(staged_changes)

      loop do
        puts "Do you want to use this commit message? (Y/R/Q)".green
        puts "Y = Yes, commit with this message".blue
        puts "R = Regenerate message".blue
        puts "Q = Quit without committing".blue
        puts ""
        puts "Commit subject: ".bold + "#{commit_message["subject"]}"
        puts "Description: ".bold + "#{commit_message["description"]}"
        puts ""
        
        case gets.chomp
        when /^[Yy]$/
          git_client.commit_all(commit_message)
          puts "All changes have been successfully committed.".green
          exit 0
        when /^[Rr]$/
          puts "Regenerating...".yellow
          puts ""
          commit_message = ai_client.get_commit_message(staged_changes)
        when /^[Qq]$/
          puts "Quit without committing.".yellow
          exit 0
        else
          puts "Invalid command. Please enter Y, R, or Q.".red.underline
          puts ""
        end
      end
    end

    private

    attr_reader :git_client, :ai_client
  end
end
