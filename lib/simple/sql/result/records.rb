# xrubocop:disable Metrics/ParameterLists

require_relative "association_loader"

class ::Simple::SQL::Result::Records < ::Simple::SQL::Result
  def initialize(records, target_type:, pg_source_oid:) # :nodoc:
    expect! records.first => Hash unless records.empty?

    super(records)

    @hash_records   = records
    @target_type    = target_type
    @pg_source_oid  = pg_source_oid

    materialize
  end

  # -- preload associations -------------------------------------------------

  AssociationLoader = ::Simple::SQL::Result::AssociationLoader

  # Preloads an association.
  #
  # This can now be used as follows:
  #
  #     scope = SQL::Scope.new("SELECT * FROM users")
  #     results = SQL.all scope, into: :struct
  #     results.preload(:organization)
  #
  # The preload method uses foreign key definitions in the database to figure out
  # which table to load from.
  #
  # This method is only available if <tt>into:</tt> was set in the call to <tt>SQL.all</tt>.
  # It raises an error otherwise.
  #
  # Parameters:
  #
  # - association: the name of the association.
  # - as: the target name of the association.
  # - order_by: if set describes ordering; see Scope#order_by.
  # - limit: if set describes limits; see Scope#order_by.
  def preload(association, as: nil, order_by: nil, limit: nil)
    expect! association => Symbol
    expect! as => [nil, Symbol]

    # resolve oid into table and schema name.
    schema, host_table = ::Simple::SQL.ask <<~SQL, @pg_source_oid
      SELECT nspname AS schema, relname AS host_table
      FROM pg_class
      JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
      WHERE pg_class.oid=$1
    SQL

    AssociationLoader.preload @hash_records, association,
                              host_table: host_table, schema: schema, as: as,
                              order_by: order_by, limit: limit
    materialize
  end

  private

  # convert the records into the target type.
  RowConverter = ::Simple::SQL::Helpers::RowConverter

  def materialize
    records = @hash_records
    records = RowConverter.convert_ary(records, into: @target_type) if @target_type != Hash
    replace(records)
  end
end
