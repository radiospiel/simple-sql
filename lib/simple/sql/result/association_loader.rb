# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength

#
# This module implements a pretty generic AssociationLoader.
#
module ::Simple::SQL::Result::AssociationLoader # :nodoc:
  extend self

  SQL = ::Simple::SQL
  H = ::Simple::SQL::Helpers

  private

  # Assuming association refers to a table, what would the table name be?
  #
  # For example, find_associated_table(:user, schema: "foo") could return
  # "foo.users", if such a table exists.
  #
  # Raises an ArgumentError if no matching table can be found.
  def find_associated_table(association, schema:)
    association = association.to_s

    tables_in_schema = ::Simple::SQL::Reflection.table_info(schema: schema).keys

    return "#{schema}.#{association}"              if tables_in_schema.include?(association)
    return "#{schema}.#{association.singularize}"  if tables_in_schema.include?(association.singularize)
    return "#{schema}.#{association.pluralize}"    if tables_in_schema.include?(association.pluralize)

    raise ArgumentError, "Don't know how to find foreign table for association #{association.inspect}"
  end

  # Given two tables returns a structure which describes a potential association
  # between these tables, based on foreign key descriptions found in the database.
  #
  # The returned struct looks something like this:
  #
  #   #<struct
  #       belonging_table="public.users",
  #       belonging_column="organization_id",
  #       having_table="public.organizations",
  #       having_column="id"
  #   >
  #
  # Raises an ArgumentError if no association can be found between these tables.
  #
  def find_matching_relation(host_table, associated_table)
    sql = <<~SQL
      WITH foreign_keys AS(
        SELECT
          tc.table_schema || '.' || tc.table_name   AS belonging_table,
          kcu.column_name                           AS belonging_column,
          ccu.table_schema || '.' || ccu.table_name AS having_table,
          ccu.column_name                           AS having_column
        FROM
          information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
        WHERE constraint_type = 'FOREIGN KEY'
      )
      SELECT * FROM foreign_keys
      WHERE (belonging_table=$1 AND having_table=$2)
        OR (belonging_table=$2 AND having_table=$1)
    SQL

    relations = SQL.all(sql, host_table, associated_table, into: :struct)
    raise ArgumentError, "Found two potential matches for the #{association.inspect} relation" if relations.length > 1
    raise ArgumentError, "Found no potential match for the #{association.inspect} relation" if relations.empty?

    relations.first
  end

  # preloads a belongs_to association.
  def preload_belongs_to(records, relation, as:)
    belonging_column = relation.belonging_column.to_sym
    having_column = relation.having_column.to_sym

    foreign_ids = H.pluck(records, belonging_column).uniq.compact

    scope = SQL::Scope.new(table: relation.having_table)
    scope = scope.where(having_column => foreign_ids)

    recs = SQL.all(scope, into: Hash)
    recs_by_id = H.by_key(recs, having_column)

    records.each do |model|
      model[as] = recs_by_id[model.fetch(belonging_column)]
    end
  end

  # preloads a has_one or has_many association.
  def preload_has_one_or_many(records, relation, as:)
    belonging_column  = relation.belonging_column.to_sym
    having_column     = relation.having_column.to_sym

    host_ids  = H.pluck(records, having_column).uniq.compact
    scope     = SQL::Scope.new(table: relation.belonging_table)
    scope     = scope.where(belonging_column => host_ids)
    recs      = SQL.all(scope, into: Hash)

    if as.to_s.singularize == as.to_s
      recs_by_id = H.by_key(recs, belonging_column) # has_one
    else
      recs_by_id = H.stable_group_by_key(recs, belonging_column) # has_many
    end

    records.each do |model|
      model[as] = recs_by_id[model.fetch(having_column)]
    end
  end

  public

  # Preloads a association into the records array.
  #
  # Parameters:
  #
  # - records: an Array of hashes.
  # - association: the name of the association
  # - host_table: the name of the table \a records has been loaded from.
  # - schema: the schema name in the database.
  def preload(records, association, host_table:, schema:)
    return records if records.empty?

    expect! records.first => Hash

    fq_host_table = "#{schema}.#{host_table}"

    associated_table = find_associated_table(association, schema: schema)
    relation         = find_matching_relation(fq_host_table, associated_table)

    if fq_host_table == relation.belonging_table
      preload_belongs_to records, relation, as: association
    else
      preload_has_one_or_many records, relation, as: association
    end
  end
end
