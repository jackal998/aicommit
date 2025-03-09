require_relative "lib/aicommit/version"

Gem::Specification.new do |s|
  s.name = "aicommit"
  s.version = Aicommit::VERSION
  s.authors = ["jackal998", "LinGaryTW"]
  s.email = ["ej_lin2000@yahoo.com.tw"]
  s.summary = "Use your own spell against you."
  s.description = "You dare use my own spells against me, Human?"
  s.homepage = "https://github.com/jackal998/aicommit"
  s.license = "MIT"
  s.required_ruby_version = ">= 3.0.0"

  s.files = Dir["CHANGELOG.md", "LICENSE", "README.md", "lib/**/*"]
  s.add_dependency "ruby-openai", "~> 7.4.0"
  s.add_dependency "dotenv", "~> 2.8.1"
  s.add_dependency "json", "~> 2.10.1"
  s.add_dependency "logger", "~> 1.6.0"
  s.add_dependency "uri", "~> 1.0.3"
  s.add_dependency "colorize", "~> 1.0.0"

  s.executables << "aicommit"
end
