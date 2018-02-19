require "simplecov"

SimpleCov.start do
  # return true to remove src from coverage 
  add_filter do |src|
    src.filename =~ /\/spec\//
  end

  minimum_coverage 96
end
