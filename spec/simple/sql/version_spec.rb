require "spec_helper"

describe SQL do
  describe "VERSION" do
    it "defines a version string" do
      # NOTE: this allows for 0.12.34beta
      expect(SQL::VERSION).to match(/^\d+\.\d+\.\d+/)
    end
  end
end
