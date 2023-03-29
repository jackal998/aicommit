require "dotenv"

class TokenManager
  ENV_PATH = "#{File.expand_path("../..", __FILE__)}/.env".freeze

  def initialize
    Dotenv.load(ENV_PATH)
  end

  def fetch(key)
    api_token = ENV[key]

    if api_token.nil? || api_token.empty?
      save_api_token_to_env!(key, gets_api_token)
    else
      api_token
    end
  end

  def write!(key)
    save_api_token_to_env!(key, gets_api_token)
  end

  private

  def gets_api_token
    puts "Please enter your OpenAI API token (or 'q' to quit):"
    api_token = gets.chomp
    if api_token.downcase == "q"
      puts "Exiting program."
      exit
    end
    api_token
  end

  def save_api_token_to_env!(key, api_token)
    File.write(ENV_PATH, "#{key}=#{api_token}")
    Dotenv.overload!(ENV_PATH)
    puts "Your API token has been saved to .env".green
    api_token
  end
end
