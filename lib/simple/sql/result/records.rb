# xrubocop:disable Metrics/ParameterLists

require_relative "association_loader"
require "simple/sql/reflection"

class ::Simple::SQL::Result::Records < ::Simple::SQL::Result
  Reflection = ::Simple::SQL::Reflection

  def initialize(records, target_type:, pg_source_oid:) # :nodoc:
    # expect! records.first => Hash unless records.empty?

    super(records)

    @hash_records   = records
    @target_type    = target_type
    @pg_source_oid  = pg_source_oid
    @associations   = []

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
    #
    # [TODO] is this still correct?
    schema, host_table = Reflection.lookup_pg_class @pg_source_oid

    AssociationLoader.preload @hash_records, association,
                              host_table: host_table, schema: schema, as: as,
                              order_by: order_by, limit: limit

    @associations << association

    materialize
  end

  private

  # convert the records into the target type.
  RowConverter = ::Simple::SQL::Helpers::RowConverter

  def materialize
    records = @hash_records
    if @target_type != Hash
      schema, host_table = Reflection.lookup_pg_class(@pg_source_oid)
      records = RowConverter.convert_row(records, associations: @associations,
                                                  into: @target_type,
                                                  fq_table_name: "#{schema}.#{host_table}")
    end
    replace(records)
  end
end
