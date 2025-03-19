require "openai"
require "json"
require_relative "../common/envs/openai_api_key"
require_relative "../common/envs/selected_model"
require_relative "../common/envs/base_branch"
require_relative "../common/envs/pr_template"
require_relative "../common/envs/pr_output_file"
require_relative "../common/ai_client"
require_relative "../common/git_client"
require "fileutils"

module PR
  class Generator
    DIFF_LIMIT = 100000

    def initialize(base_ref = nil, options = {})
      @git_client = Common::GitClient.new
      @ai_client = Common::AiClient.new
      @base_ref = base_ref
      @options = options
    end

    def run
      # Set template for this run only, without saving it to config
      if @options[:template]
        if @options[:template].is_a?(String)
          # User provided a custom template path - validate it exists
          if File.exist?(@options[:template])
            @template_path = @options[:template]
          else
            puts "Template file '#{@options[:template]}' not found. Proceeding without a template.".red
          end
        else
          # User wants to select from available templates for this run only
          template_selector = Common::Envs::PrTemplate.new
          templates = template_selector.find_pr_templates

          if !templates.empty?
            puts "Please select a PR template for this run only: (1-#{templates.size})"
            templates.each_with_index do |template, index|
              puts "#{index + 1}. #{template}"
            end

            user_input = gets.chomp
            if template_selector.validate_template_selection(user_input.to_i, templates)
              @template_path = templates[user_input.to_i - 1]
            end
          else
            puts "No PR templates found in repository."
          end
        end
      end

      base_ref = @base_ref || Common::Envs::BaseBranch.new.fetch!
      diff = git_client.diff_from_branch_root(base_ref)

      # Create a temporary AI client with the template for this run
      temp_ai_client = if @template_path
        custom_ai_client_with_template(@template_path)
      else
        ai_client
      end

      pr_description = temp_ai_client.get_pr_description(diff)

      output = format_pr_description(pr_description)

      if @options[:file]
        filename = get_output_filename
        save_to_file(output, filename)
        puts "PR description saved to #{filename}"
      end

      if @options[:clipboard]
        copy_to_clipboard(output)
        puts "PR description copied to clipboard"
      end
    rescue => e
      Aicommit.handle_error(e)
    end

    private

    attr_reader :git_client, :ai_client

    def custom_ai_client_with_template(template_path)
      custom_client = Common::AiClient.new

      # Monkey patch just for this instance to use our template
      def custom_client.get_pr_template
        if File.exist?(@_custom_template)
          File.read(@_custom_template)
        end
      end

      custom_client.instance_variable_set(:@_custom_template, template_path)

      custom_client
    end

    def get_output_filename
      if @options[:file].is_a?(String)
        # User provided a filename via command line - use it
        @options[:file]
      else
        # Use saved setting or default
        env_filename = Common::Envs::PrOutputFile.new.fetch
        env_filename || Common::Envs::PrOutputFile::DEFAULT_FILENAME
      end
    end

    def format_pr_description(pr_description)
      "# #{pr_description["title"]}\n\n#{pr_description["description"]}"
    end

    def save_to_file(content, filename)
      # Create directory if it doesn't exist
      dir_path = File.dirname(filename)
      unless File.directory?(dir_path)
        begin
          FileUtils.mkdir_p(dir_path)
          puts "Created directory: #{dir_path}".green
        rescue => e
          puts "Error creating directory: #{e.message}".red
          puts "Saving PR description to current directory instead."
          filename = File.basename(filename)
        end
      end

      # Write the file
      File.open(filename, "w") do |file|
        file.puts content
      end
    end

    def copy_to_clipboard(content)
      case RbConfig::CONFIG["host_os"]
      when /darwin/
        IO.popen("pbcopy", "w") { |f| f << content }
      when /linux/
        IO.popen("xclip -selection clipboard", "w") { |f| f << content }
      when /mswin|mingw/
        IO.popen("clip", "w") { |f| f << content }
      else
        puts "Warning: Clipboard functionality not supported on your OS".yellow
      end
    end
  end
end
