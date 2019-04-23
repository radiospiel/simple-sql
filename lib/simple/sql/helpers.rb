module ::Simple::SQL::Helpers
end

require_relative "./json.rb"
require_relative "helpers/decoder.rb"
require_relative "helpers/encoder.rb"
require_relative "helpers/row_converter.rb"

module ::Simple::SQL::Helpers
  extend self

  def stable_group_by_key(ary, key)
    hsh = Hash.new { |h, k| h[k] = [] }
    ary.each do |entity|
      group = entity.fetch(key)
      hsh[group] << entity
    end
    hsh
  end

  def pluck(ary, key)
    ary.map { |rec| rec.fetch(key) }
  end

  def by_key(ary, key)
    hsh = {}
    ary.each do |entity|
      group = entity.fetch(key)
      hsh[group] = entity
    end
    hsh
  end
end
