# require "active_support/core_ext/string/inflections"

require_relative "./helpers"

module Simple::Store::Find
  extend self

  Store = ::Simple::Store
  H     = ::Simple::Store::Helpers

  def find!(metamodels, requested_ids)
    expect! requested_ids => Array

    return [] if requested_ids.empty?

    sql = find_sql(metamodels, requested_ids)

    rows = Store.all(sql, requested_ids)

    H.return_results_if_complete!(metamodels, requested_ids, rows)
  end

  private

  def find_sql(metamodels, requested_ids)
    table_name = H.table_name_for_metamodels metamodels

    # [TODO] check for types

    case requested_ids.length
    when 1
      <<~SQL
        SELECT * FROM #{table_name} __scope__
        WHERE __scope__.id = ANY ($1)
      SQL
    else
      <<~SQL
        SELECT * FROM #{table_name} __scope__
        LEFT JOIN (
          select * from unnest($1::bigint[]) with ordinality
        ) AS __order__(id, ordinality) ON __order__.id=__scope__.id
        WHERE __scope__.id= ANY($1)
        ORDER BY __order__.ordinality
      SQL
    end
  end
end
