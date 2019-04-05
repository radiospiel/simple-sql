# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/LineLength

class Simple::Graph::Query
  def resolver(connection:)
    Simple::Graph::Resolver.new(query: self, connection: connection, associations: @_associations, attributes: @_attributes, counts: @_counts)
  end
end

require_relative "resolver/association_resolver"

class Simple::Graph::Resolver
  def initialize(connection:, query:, associations:, attributes:, counts:)
    @connection = connection
    @query        = query
    @attributes   = attributes
    @associations = associations
    @counts       = counts

    prepare_scope!
  end

  def records
    records = records_wo_associations

    # preload associated objects into records array.
    @associations.each do |mode, associated_query, options|
      AssociationResolver.resolve(mode, @query, @connection, records, associated_query, options)
    end

    records
  end

  def total_count
    @scope.count_estimate
  end

  def result
    counts = @counts.inject({}) do |hsh, attr|
      hsh.update attr => @scope.count_by_estimate(attr)
    end

    {
      records: records,
      counts: counts,
      total_count: total_count
    }
  end

  private

  # Builds a scope
  def prepare_scope!
    attributes = @attributes
    attributes = [["*"]] if attributes.empty?

    selects = []

    selects << "#{::Simple::SQL.escape_string @query.table} AS __struct__"

    pk_column = @connection.reflection.primary_key_column(@query.table).to_sym
    selects << "#{pk_column} AS __id__"

    attributes.map do |(name, value)|
      if value.is_a?(String)
        selects << "#{value} AS #{name}"
      else
        selects << name
      end
    end

    @scope = @connection.scope(table: @query.table, select: selects)
    @query.conditions.each { |condition| @scope = @scope.where(condition) }
    @scope = @scope.order_by(@query.order) if @query.order
  end

  def records_wo_associations
    if !@query.paginated?
      @connection.all(@scope, into: Hash)
    elsif @query.per <= 0
      []
    else
      paginated_scope = @scope.paginate(per: @query.per, page: @query.page)
      @connection.all(paginated_scope, into: Hash)
    end
  end
end
