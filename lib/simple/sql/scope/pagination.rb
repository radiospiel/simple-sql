# rubocop:disable Style/Not

class Simple::SQL::Scope
  # Set pagination
  def paginate(per:, page:)
    duplicate.send(:paginate!, per: per, page: page)
  end

  # Is this a paginated scope?
  def paginated?
    not @per.nil?
  end

  private

  def paginate!(per:, page:)
    @per = per
    @page = page

    self
  end

  def apply_pagination(sql, pagination:)
    return sql unless pagination == :auto && @per && @page

    raise ArgumentError, "per must be > 0" unless @per > 0
    raise ArgumentError, "page must be > 0" unless @page > 0

    "#{sql} LIMIT #{@per} OFFSET #{(@page - 1) * @per}"
  end
end
