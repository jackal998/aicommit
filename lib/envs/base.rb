require "dotenv"

module Envs
  class Base
    ENV_PATH = "#{File.expand_path("../..", __FILE__)}/.env".freeze

    def initialize
      Dotenv.load(ENV_PATH)
    end

    def fetch
      ENV[self.class::KEY]
    end

    def fetch!
      ENV[self.class::KEY] || update!
    end

    def update!
      env_value = get_env_value!
      save_to_env!(self.class::KEY, env_value)
      puts "saved to .env".green
      env_value
    end

    private

    def get_env_value!
      raise NotImplementedError
    end

    def get_user_input!
      get_user_input_display_messages.each { |msg| puts msg }
      user_input = gets.chomp
      exit_if_quit!(user_input)

      validate_user_input!(user_input)
      user_input
    end

    def validate_user_input!(user_input)
      raise NotImplementedError
    end

    def save_to_env!(env_key, value)
      File.write(ENV_PATH, updated_env_contents(env_key, value))

      Dotenv.overload!(ENV_PATH)
    end

    def updated_env_contents(env_key, value)
      # parse all into insied .env, remove the value of the env_key, and write back
      env_contents = File.exist?(ENV_PATH) ? File.read(ENV_PATH) : ""
      env_contents.tap do |str|
        str.sub!(/^#{Regexp.escape(env_key)}=.*$/, '') # remove existed env_key
        str.strip!
        str << "\n" unless env_contents.empty? || env_contents.end_with?("\n")
        str << "#{env_key}=#{value}\n"
      end
    end

    def exit_if_quit!(input)
      if input.to_s.downcase == "q"
        puts "Exiting program."
        exit
      end
    end
  end
end
