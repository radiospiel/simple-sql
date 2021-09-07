# pg 0.21 requires a file "pg/deprecated_constants" to warn about constant
# deprecations of PGconn, PGresult, and PGError. Since this is the latest
# version supported by Rails 4.2 Since this is also the latest version
# supported by ActiveRecord 4.2.* this means that with such a old version
# you would be stuck with this rather senseless warning.

# This file here replaces the original, in the hope that requiring
# "pg/deprecated_constants" would load this file and not the original -
# effectively suppressing that warning.

unless defined?(PGconn)
  PGconn   = PG::Connection
  PGresult = PG::Result
  PGError  = PG::Error
end
