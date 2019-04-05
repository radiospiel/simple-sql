module ::Simple::SQL::Helpers
end

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

  # groups an array of Hashes by the entry with a given key. The key entry must
  # exist in all records. If a group appears more than once in the incoming data,
  # the first entry wins.
  def by_key(ary, key)
    hsh = {}
    ary.reverse_each do |entity|
      group = entity.fetch(key)
      hsh[group] = entity
    end
    hsh
  end
end
