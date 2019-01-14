# require "active_support/core_ext/string/inflections"

module Simple::Store::Metamodel::Registry
  Metamodel = ::Simple::Store::Metamodel

  extend self

  @@registry = {}

  def register(metamodel)
    expect! metamodel => Metamodel
    @@registry[metamodel.name] = metamodel
  end

  def unregister(name)
    expect! name => String
    @@registry.delete name
  end

  # returns a Hash of Hashes; i.e.
  # table_name => { "type1" => metamodel1, "type2" => metamodel2, ... }
  def grouped_by_table_name
    @@registry.values.each_with_object({}) do |metamodel, hsh|
      hsh[metamodel.table_name] ||= {}
      hsh[metamodel.table_name][metamodel.name] = metamodel
    end
  end

  def lookup(name)
    @@registry[name] || raise(ArgumentError, "No suck Metamodel #{name.inspect}")
  end
end
