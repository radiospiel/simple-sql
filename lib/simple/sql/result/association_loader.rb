# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/ParameterLists
# rubocop:disable Style/GuardClause
# rubocop:disable Naming/UncommunicativeMethodParamName

require "active_support/core_ext/string/inflections"

#
# This module implements a pretty generic AssociationLoader.
#
module ::Simple::SQL::Result::AssociationLoader # :nodoc:
  extend self

  H = ::Simple::SQL::Helpers

  private

  # Assuming association refers to a table, what would the table name be?
  #
  # For example, find_associated_table(:user, schema: "foo") could return
  # "foo.users", if such a table exists.
  #
  # Raises an ArgumentError if no matching table can be found.
  def find_associated_table(connection, association, schema:)
    fq_association = "#{schema}.#{association}"

    tables_in_schema = connection.reflection.table_info(schema: schema).keys

    return fq_association              if tables_in_schema.include?(fq_association)
    return fq_association.singularize  if tables_in_schema.include?(fq_association.singularize)
    return fq_association.pluralize    if tables_in_schema.include?(fq_association.pluralize)

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
  def find_matching_relation(connection, host_table, associated_table)
    expect! host_table => /^[^.]+.[^.]+$/
    expect! associated_table => /^[^.]+.[^.]+$/

    sql = <<~SQL
      WITH foreign_keys AS(
        SELECT DISTINCT
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

    relations = connection.all(sql, host_table, associated_table, into: :struct)

    return relations.first if relations.length == 1

    description = "relation between #{host_table.inspect} and #{associated_table.inspect}"

    if relations.empty?
      raise "Didn't find any potential match for #{description}"
    else
      raise "Found two or more potential matches for #{description}"
    end
  end

  # preloads a belongs_to association.
  def preload_belongs_to(connection, records, relation, as:)
    belonging_column = relation.belonging_column.to_sym
    having_column = relation.having_column.to_sym

    foreign_ids = H.pluck(records, belonging_column).uniq.compact

    scope = connection.scope(table: relation.having_table)
    scope = scope.where(having_column => foreign_ids)

    recs = connection.all(scope, into: Hash)
    recs_by_id = H.by_key(recs, having_column)

    records.each do |model|
      model[as] = recs_by_id[model.fetch(belonging_column)]
    end
  end

  # preloads a has_one or has_many association.
  def preload_has_one_or_many(connection, records, relation, as:, order_by:, limit:)
    # To really make sense limit must be implemented using window
    # functions, because one (or, at lieast, I) would expect this code
    #
    #   organizations = SQL.all "SELECT * FROM organizations", into: Hash
    #   organizations.preload :users, limit: 2, order_by: "id DESC"
    #
    # to return up to two users **per organization**.
    #
    raise "Support for limit: is not implemented yet!" if limit
    raise "Support for order_by: is not implemented yet!" if order_by && as.to_s.singularize == as.to_s

    belonging_column  = relation.belonging_column.to_sym
    having_column     = relation.having_column.to_sym

    host_ids  = H.pluck(records, having_column).uniq.compact

    scope     = connection.scope(table: relation.belonging_table)
    scope     = scope.where(belonging_column => host_ids)
    scope     = scope.order_by(order_by) if order_by

    recs      = connection.all(scope, into: Hash)

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
  # - as: the name to sue for the association. Defaults to +association+
  def preload(connection, records, association, host_table:, schema:, as:, order_by:, limit:)
    return records if records.empty?

    expect! records.first => Hash

    as = association if as.nil?
    fq_host_table = "#{schema}.#{host_table}"

    associated_table = find_associated_table(connection, association, schema: schema)
    relation         = find_matching_relation(connection, fq_host_table, associated_table)

    if fq_host_table == relation.belonging_table
      if order_by || limit
        raise ArgumentError, "#{association.inspect} is a singular association, w/o support for order_by: and limit:"
      end

      preload_belongs_to connection, records, relation, as: as
    else
      preload_has_one_or_many connection, records, relation, as: as, order_by: order_by, limit: limit
    end
  end
end
