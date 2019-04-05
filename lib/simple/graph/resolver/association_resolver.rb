# rubocop:disable Metrics/AbcSize
# rubocop:disable Naming/PredicateName
# rubocop:disable Metrics/ParameterLists

class Simple::Graph::Resolver
  module AssociationResolver
    extend self

    H = ::Simple::SQL::Helpers

    def resolve(mode, query, connection, records, associated_query, options)
      expect! options => {
        foreign_key: [String, Symbol, nil],
        table: [String, nil]
      }

      options = options.dup
      options[:foreign_key] ||= default_foreign_key(mode, query, connection, associated_query)
      options[:table] ||= default_table(mode, query, connection, associated_query)

      associated_query = associated_query.dup
      associated_query.table = options[:table]

      send(mode, query, connection, records, associated_query, foreign_key: options[:foreign_key].to_sym)
    end

    # -- automatically determine name of associated table and foreign keys ----
    
    # determine name of associated table
    def default_table(mode, query, connection, associated_query)
      # The table setting in the associated_query, if not matching the name,
      # was explicitely set.
      return associated_query.table if associated_query.table != associated_query.name

      # determine schema of parent query. This is where we expect to find the
      # associated query.
      schema = query.table =~ /(.*)\.(.*)/ ? $1 : "public"

      # We have two candidates: a singularized and a pluralized name. We use one of
      # them if they exist, and raise an error otherwise.

      candidates = [
        "#{schema}.#{associated_query.name.to_s.pluralize}",
        "#{schema}.#{associated_query.name.to_s.singularize}"
      ]

      existing_tables = candidates & connection.reflection.tables(schema: schema)
      associated_table = existing_tables.first ||
                         raise("Cannot determine table for #{mode} association #{query.name} -> #{associated_query.name}")

      associated_table.gsub(/^public\./, "")
    end

    # determine name of associated foreign_key
    def default_foreign_key(mode, query, _connection, associated_query)
      foreign_key_query = mode == :belongs_to ? associated_query : query
      query_name = foreign_key_query.name.to_s.split(".").last
      "#{query_name.singularize}_id"
    end

    # -- resolve associations -------------------------------------------------

    # resolve a belongs_to association
    def belongs_to(_query, connection, records, associated_query, foreign_key:)
      # extract foreign key ids from records
      foreign_ids = H.pluck(records, foreign_key)

      # find load matching records
      associated_primary_key_column = connection.reflection.primary_key_column(associated_query.table).to_sym
      associated_query.conditions << { associated_primary_key_column => foreign_ids }
      associated_records = ::Simple::Graph.resolve_records(associated_query, connection: connection)

      # group matching records by keys
      associated_record_by_primary_key = H.by_key associated_records, :__id__

      # fill in associated records
      association_name = associated_query.name

      records.each do |rec|
        rec[association_name] = associated_record_by_primary_key[rec[foreign_key]]
      end
    end

    # resolve a has_many association
    def has_many(query, connection, records, associated_query, foreign_key:)
      # load associated records
      associated_records = _resolve_has_many(query, connection, records, associated_query, foreign_key: foreign_key)

      # group records by foreign key
      associated_records_by_foreign_key = H.stable_group_by_key associated_records, foreign_key
      associated_records_by_foreign_key.default = []

      # assign associated records to top level records
      primary_key_column = connection.reflection.primary_key_column(query.table).to_sym

      records.each do |rec|
        rec[associated_query.name] = associated_records_by_foreign_key[rec[primary_key_column]]
      end
    end

    # resolve a has_one association
    def has_one(query, connection, records, associated_query, foreign_key:)
      # load associated records
      associated_records = _resolve_has_many(query, connection, records, associated_query, foreign_key: foreign_key)

      # group records by foreign key
      associated_record_by_foreign_key = H.by_key associated_records, foreign_key

      # assign associated records to top level records
      primary_key_column = connection.reflection.primary_key_column(query.table).to_sym

      # fill in associated records
      records.each do |rec|
        rec[associated_query.name] = associated_record_by_foreign_key[rec[primary_key_column]]
      end
    end

    private

    def _resolve_has_many(query, connection, records, associated_query, foreign_key:)
      if associated_query.page != 1
        raise "has_one/has_many queries do not support the :page options"
      end

      # [TODO] use window functions to implement per.
      if associated_query.per
        raise "has_one/has_many queries do not yet support the :per option"
      end

      primary_key_column = connection.reflection.primary_key_column(query.table).to_sym

      associated_query.add_attribute!(foreign_key)

      # extract foreign key ids from records
      ids = H.pluck(records, primary_key_column)

      # find load matching records
      associated_query.conditions << { foreign_key => ids }

      ::Simple::Graph.resolve_records(associated_query, connection: connection)
    end
  end
end
