require "colorize"

class IgnoreFileChecker
  IGNORE_FILE_PATHS = [".gitignore"].freeze

  def initialize
  end

  def ensure_env_in_ignore_file
    IGNORE_FILE_PATHS.each do |ignore_file_path|
      next unless File.exist?(ignore_file_path)

      raw_ignore_file_content = File.read(ignore_file_path)
      return if parsed_ignore_file_content(ignore_file_path, raw_ignore_file_content).any? { |line| line.start_with?(Envs::Base::ENV_PATH) }

      append_env_to_ignore_file(ignore_file_path, raw_ignore_file_content)
    end
  end

  private

  def parsed_ignore_file_content(ignore_file_path, raw_ignore_file_content)
    case ignore_file_path
    when ".gitignore"
      raw_ignore_file_content.split("\n").map(&:strip).reject(&:empty?)
    else
      raise "Unknown ignore file path: #{ignore_file_path}"
    end
  end

  def append_env_to_ignore_file(ignore_file_path, content)
    puts "Adding #{Envs::Base::ENV_PATH} to #{ignore_file_path} file...".yellow

    case ignore_file_path
    when ".gitignore"
      content = "#{content.chomp}\n" unless content.end_with?("\n")
      content += "\n# Environment variables\n#{Envs::Base::ENV_PATH}\n"

      File.write(ignore_file_path, content)
    else
      raise "Unknown ignore file path: #{ignore_file_path}"
    end
  end
end
