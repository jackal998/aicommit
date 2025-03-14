require "openai"
require "json"
require_relative "envs/openai_api_key"
require_relative "envs/selected_model"
require_relative "envs/pr_template"

module Common
  class AiClient
    DIFF_LIMIT = 100000

    attr_reader :access_token, :client

    def initialize(access_token = nil)
      @access_token = access_token || Common::Envs::OpenaiApiKey.new.fetch!
      @client = OpenAI::Client.new(access_token: @access_token)
    end

    def get_commit_message(diff)
      messages = set_messages(diff, :commit_message)
      send_message(messages)
    end

    def get_pr_description(diff)
      messages = set_messages(diff, :pr_description)
      send_message(messages)
    end

    def send_message(messages)
      response = safe_api_request do
        @client.chat(
          parameters: {
            model: selected_model,
            response_format: {type: "json_object"},
            messages: messages,
            temperature: 0.7
          }
        )
      end

      JSON.parse(response.dig("choices", 0, "message", "content"))
    end

    def models_list
      safe_api_request { @client.models.list }
    end

    def verify_api_token!
      begin
        models_list
        true
      rescue => e
        puts "Invalid API key: #{e.message}".red
        false
      end
    end

    private

    def safe_api_request
      response = yield

      case response
      when Hash
        error_message = response.dig("error", "message")
        raise OpenAI::ConfigurationError, error_message if error_message
      end

      response
    rescue => e
      puts "Error: #{e.message}".red
      exit 1
    end

    def selected_model
      Common::Envs::SelectedModel.new.fetch!
    end

    def set_messages(diff, type)
      if diff.length > DIFF_LIMIT
        warn_lengthy_diff(diff.length)
        header_lines = diff.lines.take(50).join
        truncated_diff = header_lines + "\n...[truncated #{diff.length - DIFF_LIMIT} characters]...\n"
        truncated_diff += extract_important_changes(diff)
        message = "Truncated diff (showing approximately #{DIFF_LIMIT} out of #{diff.length} characters):\n#{truncated_diff}"
      else
        message = diff
      end

      prompt = case type
      when :commit_message
        prompt_for_commit_message(message)
      when :pr_description
        prompt_for_pr_description(message)
      end

      [{"role" => "user", "content" => prompt}]
    end

    def extract_important_changes(diff)
      important_content = []
      current_file = nil
      line_count = 0
      sample_size = 5

      diff.lines.each do |line|
        if line.start_with?("diff --git")
          current_file = line
          important_content << current_file
          line_count = 0
        elsif current_file && line_count < sample_size && (line.start_with?("+") || line.start_with?("-"))
          important_content << line
          line_count += 1
        end
      end

      important_content.join[0...DIFF_LIMIT / 2]
    end

    def prompt_for_commit_message(input)
      <<~PROMPT
        Given the git diff below, write a commit message following the conventional commit format: <type>(<scope>): <description>

        Keep the first line under 72 characters, add a blank line, and wrap subsequent text at 72 characters. Be direct and concise, focusing on WHY the change was made. Format the response as a JSON object with 'subject' as the first line of the commit message, and 'description' as the remainder, separated by a newline.

        Here's the diff:
        #{input}

        Suggestions for <type>:
        - feat: New features
        - fix: Bug fixes
        - docs: Documentation updates
        - style: Code style changes (formatting, etc.)
        - refactor: Code restructuring with no behavior changes
        - perf: Performance improvements
        - test: Adding or updating tests
        - chore: Routine tasks, maintenance, dependencies
      PROMPT
    end

    def prompt_for_pr_description(input)
      template = get_pr_template
      template_instruction = if template
        "7. Use the following PR template as a guide for structuring your response:\n\n#{template}\n\n"
      else
        ""
      end

      <<~PROMPT
        Generate a comprehensive PR description for the following Git diff. Create a clear narrative about what the changes accomplish.

        Here's the diff:
        #{input}

        Requirements:
        1. Format as markdown
        2. Begin with a descriptive title prefixed with "# "
        3. Include sections:
           - Summary of changes
           - Related issues or motivation
           - Implementation details
           - Testing notes or instructions
           - Breaking changes or deprecations (if applicable)
        4. Highlight important files changed
        5. Omit git metadata (like "diff --git" lines)
        6. Format response as a JSON object with 'title' and 'description' keys
        #{template_instruction}
      PROMPT
    end

    def warn_lengthy_diff(size)
      puts "=================================================================".yellow
      puts "Warning: The diff is quite large (#{size} characters) and will be truncated for the AI".yellow
      puts "This may result in a less accurate commit message".yellow
      puts "Consider making smaller, more focused commits".yellow
      puts "=================================================================".yellow
    end

    def get_pr_template
      pr_template_path = Common::Envs::PrTemplate.new.fetch!
      return nil unless pr_template_path
      
      if File.exist?(pr_template_path)
        File.read(pr_template_path)
      else
        nil
      end
    end
  end
end
