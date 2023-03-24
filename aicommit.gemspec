Gem::Specification.new do |s|
  s.name          = "aicommit"
  s.version       = "0.0.8"
  s.authors       = ["jackal998", "LinGaryTW"]
  s.email         = ["ej_lin2000@yahoo.com.tw"]
  s.summary       = "Use your own spell against you."
  s.description   = "You dare use my own spells against me, Human?"
  s.homepage      = "https://github.com/jackal998/aicommit"
  s.license       = "MIT"

  s.files         = Dir["CHANGELOG.md", "LICENSE", "README.md", "lib/**/*"]
  s.add_dependency "git", "~> 1.14.0"
  s.add_dependency "ruby-openai", "~> 3.4.0"
  s.add_dependency "dotenv", "~> 2.8.1"

  s.executables << "aicommit"
end
