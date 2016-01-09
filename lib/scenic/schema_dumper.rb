require "rails"

module Scenic
  # @api private
  module SchemaDumper
    # Total hack, but in Rails 5, Scenic is caching a different ActiveRecord::Base.connection
    # than db:schema:load is using, so the views try to execute in a different connection
    # inside the same transaction
    def reconnect(stream)
      stream.puts <<-CONNECT

  Scenic.configure do |config|
    config.database = Scenic::Adapters::Postgres.new(ActiveRecord::Base.connection)
  end
      CONNECT
    end

    def tables(stream)
      super
      reconnect(stream)
      views(stream)
    end

    def views(stream)
      views_in_database.select { |view| !ignored?(view.name) }.each do |view|
        stream.puts(view.to_schema)
      end
    end

    def views_in_database
      @views_in_database ||= Scenic.database.views
    end

    private

    unless ActiveRecord::SchemaDumper.instance_methods(false).include?(:ignored?)
      # This method will be present in Rails 4.2.0 and can be removed then.
      def ignored?(table_name)
        ["schema_migrations", ignore_tables].flatten.any? do |ignored|
          case ignored
          when String; remove_prefix_and_suffix(table_name) == ignored
          when Regexp; remove_prefix_and_suffix(table_name) =~ ignored
          else
            raise StandardError, "ActiveRecord::SchemaDumper.ignore_tables accepts an array of String and / or Regexp values."
          end
        end
      end
    end
  end
end
