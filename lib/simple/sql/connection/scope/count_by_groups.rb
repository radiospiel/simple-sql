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
    @connection.all "SELECT DISTINCT #{sql_fragment} FROM (#{sql}) sq", *args
  end

  def count_by(sql_fragment)
    expect! sql_fragment => String

    sql = order_by(nil).to_sql(pagination: false)

    recs = @connection.all "SELECT COUNT(*) AS count, #{sql_fragment} AS group FROM (#{sql}) sq GROUP BY #{sql_fragment}", *args

    # if we count by a single value (e.g. `count_by("role_id")`) each entry in recs consists of an array [group_value, count].
    # The resulting Hash will have entries of group_value => count.
    if recs.first&.length == 2
      recs.each_with_object({}) do |count_and_group, hsh|
        count, group = *count_and_group
        hsh[group] = count
      end
    else
      recs.each_with_object({}) do |count_and_group, hsh|
        count, *group = *count_and_group
        hsh[group] = count
      end
    end
  end

  private

  # cost estimate threshold for count_by method. Can be set to false, true, or
  # a number.
  #
  # Note that cost estimates are problematic, since they are not reported in
  # any "real" unit, meaning any comparison really is a bit pointless.
  COUNT_BY_ESTIMATE_COST_THRESHOLD = 10_000

  # estimates the cost to run a sql query. If COUNT_BY_ESTIMATE_COST_THRESHOLD
  # is set and the cost estimate is less than COUNT_BY_ESTIMATE_COST_THRESHOLD
  # \a count_by_estimate is using the estimating code path.
  def use_count_by_estimate?(sql_group_by_fragment)
    case COUNT_BY_ESTIMATE_COST_THRESHOLD
    when true then true
    when false then false
    else
      # estimate the effort to exact counting over all groups.
      base_sql  = order_by(nil).to_sql(pagination: false)
      count_sql = "SELECT COUNT(*) FROM (#{base_sql}) sq GROUP BY #{sql_group_by_fragment}"
      cost      = @connection.estimate_cost count_sql, *args

      cost >= COUNT_BY_ESTIMATE_COST_THRESHOLD
    end
  end

  public

  # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
  def count_by_estimate(sql_fragment)
    expect! sql_fragment => String

    return count_by(sql_fragment) unless use_count_by_estimate?(sql_fragment)

    # iterate over all groups, estimating the count for each.
    #
    # For larger groups we'll use that estimate - preventing a full table scan.
    # Groups smaller than EXACT_COUNT_THRESHOLD are counted exactly - in the
    # hope that this query can be answered from an index.

    #
    # Usually Simple::SQL.all normalizes each result row into its first value,
    # if the row only consists of a single value. Here, however, we don't
    # know the width of a group; so to understand this we just add a dummy
    # value to the sql_fragment and then remove it again.
    #
    groups = enumerate_groups("1 AS __dummy__, #{sql_fragment}")
    groups = groups.each(&:shift)

    # no groups? well, then...
    return {} if groups.empty?

    #
    # The estimating code only works for groups of size 1. This is a limitation
    # of simple-sql - for larger groups we would have to be able to encode arrays
    # of arrays on their way to the postgres server. We are not able to do that
    # currently.
    #
    group_size = groups.first&.length
    if group_size > 1
      return count_by(sql_fragment)
    end

    # The code below only works for groups of size 1
    groups = groups.map(&:first)

    #
    # Now we estimate the count of entries in each group. For large groups we
    # just use the estimate - because it is usually pretty close to being correct.
    # Small groups are collected in the `sparse_groups` array, to be counted
    # exactly later on.
    #

    counts = {}

    sparse_groups = []
    base_sql = order_by(nil).to_sql(pagination: false)

    var_name = "$#{@args.count + 1}"

    groups.each do |group|
      scope = @connection.scope("SELECT * FROM (#{base_sql}) sq WHERE #{sql_fragment}=#{var_name}", args + [group])

      estimated_count = scope.send(:estimated_count)
      counts[group] = estimated_count
      sparse_groups << group if estimated_count < EXACT_COUNT_THRESHOLD
    end

    # fetch exact counts in all sparse_groups
    unless sparse_groups.empty?
      sparse_counts = @connection.all <<~SQL, *args, sparse_groups
        SELECT #{sql_fragment} AS group, COUNT(*) AS count
        FROM (#{base_sql}) sq
        WHERE #{sql_fragment} = ANY(#{var_name})
        GROUP BY #{sql_fragment}
      SQL

      counts.update sparse_counts.to_h
    end

    counts
  end
end
