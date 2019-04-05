# rubocop:disable Metrics/ParameterLists
# rubocop:disable Style/MultipleComparison

module Simple
  module Graph
  end
end

require_relative "graph/query"
require_relative "graph/resolver"

module Simple::Graph
  extend self

  def query(*args, &block)
    Query.new(*args).tap do |obj|
      obj.instance_eval(&block) if block
    end
  end

  def resolve(query, connection: nil, conditions: nil, per: nil, page: nil, order: nil, internal_attributes: false)
    dupe = query.dup.tap do |d|
      d.per = per                 if per
      d.page = page               if page
      d.order = order             if order
      d.conditions += conditions  if conditions
    end

    connection ||= ::Simple::SQL
    result = dupe.resolver(connection: connection).result
    remove_internal_attributes(result[:records]) unless internal_attributes
    result
  end

  def resolve_records(query, connection: nil)
    connection ||= ::Simple::SQL
    query.resolver(connection: connection).records
  end

  private

  def remove_internal_attributes(records)
    case records
    when Array
      records.each { |rec| remove_internal_attributes(rec) }
    when Hash
      records.reject! { |key, _| key == :__id__ || key == :__struct__ }
      records.each { |_, value| remove_internal_attributes(value) }
    end
  end
end
