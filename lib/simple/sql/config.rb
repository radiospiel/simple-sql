# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/PerceivedComplexity

# module to determine database configuration
module Simple::SQL::Config
  extend self

  # parse a DATABASE_URL, return PG::Connection settings.
  def parse_url(url)
    expect! url => /^postgres(ql)?s?:\/\//

    require "uri"
    uri = URI.parse(url)
    raise ArgumentError, "Invalid URL #{url}" unless uri.hostname && uri.path

    config = {
      dbname: uri.path.sub(%r{^/}, ""),
      host:   uri.hostname
    }
    config[:port] = uri.port if uri.port
    config[:user] = uri.user if uri.user
    config[:password] = uri.password if uri.password
    config[:sslmode] = uri.scheme == "postgress" || uri.scheme == "postgresqls" ? "require" : "prefer"
    config
  end

  # determines the database_url from either the DATABASE_URL environment setting
  # or a config/database.yml file.
  def determine_url(path: nil)
    if path
      database_url_from_database_yml(path)
    elsif ENV["DATABASE_URL"]
      ENV["DATABASE_URL"]
    else
      database_url_from_database_yml("config/database.yml")
    end
  end

  private

  def database_url_from_database_yml(path)
    abc = load_activerecord_base_configuration(path: path, env: ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development")

    username, password, host, port, database = abc.values_at "username", "password", "host", "port", "database"

    URI::Generic.build(
      scheme: "postgres",
      userinfo: [username, (":" if password), password].join,
      host: host || "localhost",
      port: port,
      path: "/#{database}"
    ).to_s
  end

  def load_activerecord_base_configuration(path:, env:)
    require "yaml"
    database_config = if Psych::VERSION > '4.0'
      YAML.safe_load(File.read(path), aliases: true)
    else
      YAML.safe_load(File.read(path), [], [], true)
    end
    
    env ||= ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development"

    database_config[env] ||
      database_config["defaults"] ||
      raise("Invalid or missing database configuration in #{path} for #{env.inspect} environment")
  end
end
