# rubocop:disable Style/Not
# rubocop:disable Style/MultipleComparison
# rubocop:disable Style/IfUnlessModifier
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/PerceivedComplexity

# The Simple::SQL::Scope class helps building scopes; i.e. objects
# that start as a quite basic SQL query, and allow one to add
# sql_fragments as where conditions.
class Simple::SQL::Scope
  SELF = self

  attr_reader :args
  attr_reader :per, :page

  # Build a scope object
  def initialize(sql)
    @sql = sql
    @args = []
    @filters = []
  end

  private

  def duplicate
    dupe = SELF.new(@sql)
    dupe.instance_variable_set :@args, @args.dup
    dupe.instance_variable_set :@filters, @filters.dup
    dupe.instance_variable_set :@per, @per
    dupe.instance_variable_set :@page, @page
    dupe
  end

  public

  # scope = Scope.new("SELECT * FROM tablename")
  # scope = scope.where("id > ?", 12)
  #
  # The placeholder (usually a '?') is being replaced with the numbered
  # argument (since postgres is using $1, $2, etc.) If your SQL fragment
  # uses '?' as part of some fixed text you must use an alternative
  # placeholder symbol.
  #
  # TODO: Add support for hash arguments, i.e.
  # scope = scope.where(title: "foobar")
  def where(sql_fragment, arg = :__dummy__no__arg, placeholder: "?")
    duplicate.send(:where!, sql_fragment, arg, placeholder: placeholder)
  end

  private

  def where!(sql_fragment, arg = :__dummy__no__arg, placeholder: "?")
    if arg == :__dummy__no__arg
      @filters << sql_fragment
    else
      @args << arg
      @filters << sql_fragment.gsub(placeholder, "$#{@args.length}")
    end

    self
  end

  public

  # Set pagination
  def paginate(per:, page:)
    duplicate.send(:paginate!, per: per, page: page)
  end

  private

  def paginate!(per:, page:)
    @per = per
    @page = page

    self
  end

  public

  # Is this a paginated scope?
  def paginated?
    not @per.nil?
  end

  # generate a sql query
  def to_sql(pagination: :auto)
    raise ArgumentError unless pagination == :auto || pagination == false

    sql = @sql
    active_filters = @filters.compact
    unless active_filters.empty?
      sql += " WHERE (" + active_filters.join(") AND (") + ")"
    end
    if pagination == :auto && @per && @page
      raise ArgumentError, "per must be > 0" unless @per > 0
      raise ArgumentError, "page must be > 0" unless @page > 0

      sql += "LIMIT #{@per} OFFSET #{(@page - 1) * @per}"
    end

    sql
  end

  # The Scope::PageInfo module can be mixed into other objects to
  # hold total_count, total_pages, and current_page.
  module PageInfo
    attr_reader :total_count, :total_pages, :current_page

    def self.attach(results, total_count:, per:, page:)
      results.extend(self)
      results.instance_variable_set :@total_count, total_count
      results.instance_variable_set :@total_pages, (total_count + (per - 1)) / per
      results.instance_variable_set :@current_page, page
      results
    end
  end
end
