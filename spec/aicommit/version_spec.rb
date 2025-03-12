require "aicommit/version"

RSpec.describe Aicommit do
  describe "VERSION" do
    it "has a version number" do
      expect(Aicommit::VERSION).not_to be nil
      expect(Aicommit::VERSION).to be_a(String)
      expect(Aicommit::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end
end
