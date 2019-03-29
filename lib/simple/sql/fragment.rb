# rubocop:disable Style/StructInheritance
module Simple
  module SQL
    class Fragment < Struct.new(:to_sql)
    end

    def fragment(str)
      Fragment.new(str)
    end
  end
end
