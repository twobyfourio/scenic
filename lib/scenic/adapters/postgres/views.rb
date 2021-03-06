module Scenic
  module Adapters
    class Postgres
      # Fetches defined views from the postgres connection.
      # @api private
      class Views
        def initialize(connection)
          @connection = connection
        end

        # All of the views that this connection has defined.
        #
        # This will include materialized views if those are supported by the
        # connection.
        #
        # @return [Array<Scenic::View>]
        def all
          views_from_postgres.map(&method(:to_scenic_view))
        end

        private

        attr_reader :connection

        def views_from_postgres
          connection.execute(<<-SQL)
            SELECT
              c.relname as viewname,
              pg_get_viewdef(c.oid) AS definition,
              c.relkind AS kind
            FROM pg_class c
              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE
              c.relkind IN ('m', 'v')
              AND c.relname NOT IN (SELECT extname FROM pg_extension)
              AND n.nspname = ANY (current_schemas(false))
            ORDER BY c.oid
          SQL
        end

        def to_scenic_view(result)
          Scenic::View.new(
            name: result["viewname"],
            definition: result["definition"].strip,
            materialized: result["kind"] == "m",
          )
        end
      end
    end
  end
end
