require_relative "base"

module Common
  module Envs
    class PrTemplate < Base
      KEY = "AI_COMMIT_PR_TEMPLATE".freeze
      
      # Locations where GitHub PR templates can be stored
      TEMPLATE_PATHS = {
        files: [
          "pull_request_template.md",
          "docs/pull_request_template.md",
          ".github/pull_request_template.md"
        ],
        dir: ".github/PULL_REQUEST_TEMPLATE"
      }.freeze
      
      def initialize(custom_path = nil)
        super()
        @custom_path = custom_path
      end
      
      def update!(provided_value = nil)
        if provided_value
          validate_template_path!(provided_value)
          super(provided_value)
        elsif @custom_path
          validate_template_path!(@custom_path)
          super(@custom_path)
        else
          value = get_env_value!
          # Only save if we have a non-nil value to save
          if value
            save_to_env!(self.class::KEY, value)
            puts "#{self.class::KEY} saved to .env".green
            value
          else
            puts "No PR template found or selected. Configuration not updated.".yellow
            fetch
          end
        end
      end
      
      # Make find_pr_templates public so it can be used by other classes
      def find_pr_templates
        @_templates ||= begin
          templates = []
          
          # Check for individual template files
          TEMPLATE_PATHS[:files].each do |path|
            templates << path if File.exist?(path)
          end
          
          # Check for multiple templates in directories
          if Dir.exist?(TEMPLATE_PATHS[:dir])
            Dir.glob(File.join(TEMPLATE_PATHS[:dir], "*.md")).each do |file|
              templates << file
            end
          end
          
          templates
        end
      end
      
      def validate_template_selection(selection_index, templates)
        unless [*(1..templates.size)].include?(selection_index)
          puts "Invalid selection, using default template.".red
          return false
        end
        true
      end
      
      private

      def get_env_value!
        if @custom_path
          if File.exist?(@custom_path)
            return @custom_path
          else
            puts "Specified template file '#{@custom_path}' not found.".red
            exit 1
          end
        end
        
        templates = find_pr_templates
        
        if templates.empty?
          puts "No PR templates found in repository."
          return nil
        end
        
        templates[get_user_input!.to_i - 1]
      end

      def get_user_input_display_messages
        ["Please select a PR template: (1-#{find_pr_templates.size})"].tap do |display_messages|
          find_pr_templates.each_with_index do |item, index|
            display_messages << "#{index + 1}. #{item}"
          end
        end
      end

      def validate_user_input!(user_input)
        unless [*(1..find_pr_templates.size)].include?(user_input.to_i)
          puts "Invalid selection, exiting program."
          exit
        end

        user_input
      end
      
      def validate_template_path!(path)
        unless path.nil? || File.exist?(path)
          puts "Error: Template file '#{path}' not found.".red
          exit 1
        end
        path
      end
      
      def get_template_content(template_path)
        File.read(template_path) if template_path && File.exist?(template_path)
      end
    end
  end
end 
