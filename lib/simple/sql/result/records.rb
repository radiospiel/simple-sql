require_relative "association_loader"

class ::Simple::SQL::Result::Records < ::Simple::SQL::Result::Rows
  def initialize(records, target_type:, pg_source_oid:)
    expect! records.first => Hash unless records.empty?

    super(records)

    @hash_records   = records
    @target_type    = target_type
    @pg_source_oid  = pg_source_oid

    materialize
  end

  # -- preload associations -------------------------------------------------

  AssociationLoader = ::Simple::SQL::Result::AssociationLoader

  def preload(association, as: nil)
    expect! association => Symbol
    expect! as => [ nil, Symbol ]

    # resolve oid into table and schema name.
    schema, host_table = SQL.ask <<~SQL, @pg_source_oid
      SELECT nspname AS schema, relname AS host_table
      FROM pg_class
      JOIN pg_namespace ON pg_namespace.oid=pg_class.relnamespace
      WHERE pg_class.oid=$1
    SQL

    AssociationLoader.preload @hash_records, association.to_sym, host_table: host_table, schema: schema, as: as
    materialize
  end

  private

  # convert the records into the target type.
  RowConverter = ::Simple::SQL::Helpers::RowConverter

  def materialize
    records = @hash_records
    records = RowConverter.convert(records, into: @target_type) if @target_type != Hash

    replace(records)
  end
end
