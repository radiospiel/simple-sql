# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/MethodLength

class Simple::SQL::Connection::Scope
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

    cost = @connection.estimate_cost "SELECT MIN(#{sql_fragment}) FROM (#{sql}) sq", *args

    # cost estimates are good, but are hard to check against a hard coded value.
    # see https://issues.mediafellows.com/issues/75232
    #
    # if cost > 10_000
    #   raise "enumerate_groups(#{sql_fragment.inspect}) takes too much time. Make sure to create a suitable index"
    # end

    groups = []
    var_name = "$#{@args.count + 1}"
    cur = @connection.ask "SELECT MIN(#{sql_fragment}) FROM (#{sql}) sq", *args

    while cur
      groups << cur
      cur = @connection.ask "SELECT MIN(#{sql_fragment}) FROM (#{sql}) sq"" WHERE #{sql_fragment} > #{var_name}", *args, cur
    end

    groups
  end

  def count_by(sql_fragment)
    sql = order_by(nil).to_sql(pagination: false)

    recs = @connection.all "SELECT #{sql_fragment} AS group, COUNT(*) AS count FROM (#{sql}) sq GROUP BY #{sql_fragment}", *args
    Hash[recs]
  end

  def count_by_estimate(sql_fragment)
    sql = order_by(nil).to_sql(pagination: false)
    cost = @connection.estimate_cost "SELECT COUNT(*) FROM (#{sql}) sq GROUP BY #{sql_fragment}", *args

    return count_by(sql_fragment) if cost < 10_000

    # iterate over all groups, estimating the count for each. If the count is
    # less than EXACT_COUNT_THRESHOLD we ask for the exact count in that and
    # similarily sparse groups.
    var_name = "$#{@args.count + 1}"

    counts = {}
    sparse_groups = []
    enumerate_groups(sql_fragment).each do |group|
      scope = @connection.scope("SELECT * FROM (#{sql}) sq WHERE #{sql_fragment}=#{var_name}", args + [group])
      estimated_count = scope.send(:estimated_count)
      counts[group] = estimated_count
      sparse_groups << group if estimated_count < EXACT_COUNT_THRESHOLD
    end

    # fetch exact counts in all sparse_groups
    unless sparse_groups.empty?
      sparse_counts = @connection.all <<~SQL, *args, sparse_groups
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
