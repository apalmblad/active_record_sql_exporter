module ActiveRecord::SqlExporter
  # ------------------------------------------------------------------ included?
  def included?( klass )
    klass.include( InstanceMethods )
  end
  module InstanceMethods
    # ------------------------------------------------------------------- to_sql
    def to_sql( args = {}, check_list = [] )
      sql = ''
      return sql if check_list.include?( self )
      check_list << self

      unless args[:no_transaction]
        sql += "BEGIN;"
      end
      quoted_attributes = attributes_with_quotes
      sql += "\nINSERT INTO #{self.class.quoted_table_name} " +
      "(#{quoted_column_names.join(', ')}) " +
      "VALUES(#{quoted_attributes.values.join(', ')})"
      unless args[:no_update]
        sql += " ON DUPLICATE KEY UPDATE #{quoted_comma_pair_list(connection, quoted_attributes)}"
      end
      sql += ';'
      sql += convert_relations_to_sql( self.class.reflections, check_list, :no_update => args[:no_update] )
      sql += "\nCOMMIT;" unless args[:no_transaction]
      return sql
    end
    # ---------------------------------------------------------- build_check_sql
    def build_check_sql( check_list )
      return '' if check_list.include?( self )
      check_list << self
      "\nIF( NOT EXISTS( SELECT * FROM #{self.class.quoted_table_name} WHERE #{connection.quote_column_name(self.class.primary_key)} = #{quote_value(id)} ) THEN ROLLBACK; END IF;"
    end
    # ---------------------------------------- convert_has_many_relations_to_sql
    def convert_relations_to_sql( reflections, check_list, args = {} )
      args[:no_transaction] = true
      sql = ''
      reflections.each_pair do |key, value|
        case value.macro
        when :has_one
          singleton_method( key ) do |e|
            sql += e.to_sql( args, check_list )
          end
        when :has_many, :has_and_belongs_to_many
          send( key ).each{ |x| sql += x.to_sql( args, check_list ) }
        when :belongs_to
          singleton_method( key ) do |e|
            sql += e.build_check_sql( check_list )
          end
        else
          raise "Unhandled reflection: #{value.macro}"
        end
      end
      return sql
    end
    # --------------------------------------------------------- singleton_method
    def singleton_method( key )
      if v = self.send( key )
        yield v
      end
    end
  end
end
