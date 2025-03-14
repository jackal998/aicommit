require_relative "base"
require "fileutils"

module Common
  module Envs
    class PrOutputFile < Base
      KEY = "AICOMMIT_PR_OUTPUT_FILE".freeze
      DEFAULT_FILENAME = "PR_DESCRIPTION.md".freeze

      def update!(provided_value = nil)
        if provided_value
          super(validate_filename!(provided_value))
        else
          super
        end
      end

      private

      def get_env_value!
        get_user_input!
      end

      def get_user_input_display_messages
        [
          "Enter the default filename or path for PR descriptions (default: #{DEFAULT_FILENAME})",
          "(Press Enter to use default, or Q to quit)"
        ]
      end

      def validate_user_input!(user_input)
        validate_filename!(user_input)
      end

      def validate_filename!(filename)
        return DEFAULT_FILENAME if filename.to_s.strip.empty?

        # Allow paths but ensure they're valid
        if filename.include?("/") || filename.include?("\\")
          # Extract directory part to validate
          dir_path = File.dirname(filename)

          # Check if directory exists or can be created
          unless Dir.exist?(dir_path)
            # Display message but don't exit in interactive mode
            if caller_locations(1, 1)[0].label == "validate_user_input!"
              puts "Warning: Directory '#{dir_path}' doesn't exist. It will be created when saving PR descriptions.".yellow
            else
              # Try to create directory to validate path
              begin
                FileUtils.mkdir_p(dir_path)
                puts "Created directory: #{dir_path}".green
                FileUtils.rmdir(dir_path) unless Dir.exist?(dir_path) # Clean up if it was newly created
              rescue => e
                puts "Error: Invalid path. #{e.message}".red
                return get_user_input! if caller_locations(1, 1)[0].label == "validate_user_input!"
                exit 1
              end
            end
          end
        end

        # Validate that the filename isn't a directory
        if File.directory?(filename)
          puts "Error: '#{filename}' is a directory, not a file.".red
          return get_user_input! if caller_locations(1, 1)[0].label == "validate_user_input!"
          exit 1
        end

        filename
      end
    end
  end
end
