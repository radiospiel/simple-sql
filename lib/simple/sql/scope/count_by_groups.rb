# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength

class Simple::SQL::Scope
  # Potentially fast implementation of returning all different values for a specific group.
  #
  # For example:
  #
  #   Scope.new("SELECT * FROM users").enumerate_groups("gender") -> [ "female", "male" ]
  #
  # It is possible to enumerate over multiple attributes, for example:
  #
  #   scope.enumerate_groups fragment: "ARRAY[workflow, queue]"
  #
  # In any case it is important that an index exists that the database can use to group
  # by the +sql_fragment+, for example:
  #
  #   CREATE INDEX ix3 ON table((ARRAY[workflow, queue]));
  #
  def enumerate_groups(sql_fragment)
    sql = order_by(nil).to_sql(pagination: false)

    _, max_cost = ::Simple::SQL.costs "SELECT MIN(#{sql_fragment}) FROM (#{sql}) sq", *args
    raise "enumerate_groups: takes too much time. Make sure to create a suitable index" if max_cost > 10_000

    groups = []
    var_name = "$#{@args.count + 1}"
    cur = ::Simple::SQL.ask "SELECT MIN(#{sql_fragment}) FROM (#{sql}) sq", *args

    while cur
      groups << cur
      cur = ::Simple::SQL.ask "SELECT MIN(#{sql_fragment}) FROM (#{sql}) sq"" WHERE #{sql_fragment} > #{var_name}", *args, cur
    end

    groups
  end

  def count_by(sql_fragment)
    sql = order_by(nil).to_sql(pagination: false)

    recs = ::Simple::SQL.all "SELECT #{sql_fragment} AS group, COUNT(*) AS count FROM (#{sql}) sq GROUP BY #{sql_fragment}", *args
    Hash[recs]
  end

  def fast_count_by(sql_fragment)
    sql = order_by(nil).to_sql(pagination: false)

    _, max_cost = ::Simple::SQL.costs "SELECT COUNT(*) FROM (#{sql}) sq GROUP BY #{sql_fragment}", *args

    return count_by(sql_fragment) if max_cost < 10_000

    # iterate over all groups, estimating the count for each. If the count is
    # less than EXACT_COUNT_THRESHOLD we ask for the exact count in that and
    # similarily sparse groups.
    var_name = "$#{@args.count + 1}"

    counts = {}
    sparse_groups = []
    enumerate_groups(sql_fragment).each do |group|
      scope = ::Simple::SQL::Scope.new("SELECT * FROM (#{sql}) sq WHERE #{sql_fragment}=#{var_name}", *args, group)
      counts[group] = scope.send(:estimated_count)
      sparse_groups << group if estimated_count < EXACT_COUNT_THRESHOLD
    end

    # fetch exact counts in all sparse_groups
    unless sparse_groups.empty?
      sparse_counts = ::Simple::SQL.all <<~SQL, *args, sparse_groups
        SELECT #{sql_fragment} AS group, COUNT(*) AS count
        FROM (#{sql}) sq
        WHERE #{sql_fragment} = ANY(#{var_name})
        GROUP BY #{sql_fragment}
      SQL

      counts.update Hash[sparse_counts]
    end

    counts
  end
end
