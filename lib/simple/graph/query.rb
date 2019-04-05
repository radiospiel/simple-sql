# rubocop:disable Style/MethodMissingSuper
# rubocop:disable Naming/PredicateName
# rubocop:disable Metrics/AbcSize

class Simple::Graph::Query
  SELF = self

  attr_reader :name
  attr_accessor :conditions

  attr_accessor :table

  attr_reader :per
  attr_reader :page
  attr_reader :order

  def initialize(name, opts = {})
    conditions, per, page, order, table = opts.values_at(:conditions, :per, :page, :order, :table)

    @name = name
    @conditions = conditions ? Array(conditions) : []

    self.table = table || name
    self.per   = per
    self.page  = page || 1
    self.order = order

    @_associations = []
    @_attributes = []
    @_counts = []
  end

  def per=(per)
    expect! per => [Integer, nil]
    @per = per
  end

  def page=(page)
    expect! page => [Integer, nil]
    @page = page
  end

  def order=(order)
    expect! order => [Symbol, String, nil]
    @order = order
  end

  def paginated?
    page && per
  end

  # --- DSL -------------------------------------------------------------------

  class Aspect
    def initialize(query)
      @query = query
    end
  end

  # --- collection parameters -------------------------------------------------

  class Collection < Aspect
    def table(table)
      @query.table = table
    end

    def per(per)
      @query.per = per
    end

    def page(page)
      @query.page = page
    end

    def order(order)
      @query.order = order
    end
  end

  def collection(&block)
    Collection.new(self).instance_eval(&block)
  end

  # --- attribute specifications ----------------------------------------------

  def add_attribute!(name, sql = nil)
    existing_attribute = @_attributes.find { |attribute| attribute == name }
    new_attribute = sql.nil? ? [name] : [name, sql]

    if existing_attribute && new_attribute != existing_attribute
      raise "Overwriting existing attribute with changed definition: #{existing_attribute.inspect} vs #{new_attribute.inspect}"
    end

    @_attributes << new_attribute
  end

  def any
    @_attributes << ["*"]
  end

  class Records < Aspect
    def method_missing(name, *args)
      @query.add_attribute! name, *args
    end

    def respond_to_missing?(_sym, _include_all)
      true
    end
  end

  def records(&block)
    Records.new(self).instance_eval(&block)
  end

  # --- counts specifications -------------------------------------------------

  class Counts < Aspect
    def counts
      @counts ||= []
    end

    def method_missing(sym, *args)
      case args.length
      when 0
        counts << sym
      else
        raise "Invalid count specification"
      end
    end

    def respond_to_missing?(_sym, _include_all)
      true
    end
  end

  def counts(&block)
    adapter = Counts.new(self)
    adapter.instance_eval(&block)
    @_counts.concat adapter.counts
  end

  # --- associations ----------------------------------------------------------

  def add_association!(kind, name, opts, &block)
    existing_association = @_associations.find { |association| association.name == name }
    if existing_association
      raise "Cannot redefine an existing association"
    end

    associated_query = ::Simple::Graph.query(name, opts, &block)

    @_associations << [kind, associated_query, opts]
  end

  def belongs_to(name, opts = {}, &block)
    add_association! :belongs_to, name, opts, &block
  end

  def has_many(name, opts = {}, &block)
    add_association! :has_many, name, opts, &block
  end

  def has_one(name, opts = {}, &block)
    add_association! :has_one, name, opts, &block
  end
end
