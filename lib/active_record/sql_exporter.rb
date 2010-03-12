module ActiveRecord::SqlExporter
  # ------------------------------------------------------------------ included?
  def included?( klass )
    klass.include( InstanceMethods )
  end
  module InstanceMethods
    CREATION_NODE = 1
    EXISTENCE_CHECK_NODE = 2
    # ------------------------------------------------------------------- to_sql
    def to_sql( args = {}, check_list = [] )
      tree = {}
      build_export_tree( tree )
      sql = ''
      unless args[:no_transaction]
        sql += "BEGIN;"
      end
      tree.keys.each do |klass|
        tree[klass].keys.each do |id|
          node = tree[klass][id]
          if node[:type] == EXISTENCE_CHECK_NODE
            sql += node[:object].build_check_sql
          elsif node[:type] == CREATION_NODE
            sql += node[:object].sql_restore_string
          end
        end
      end
      sql += "COMMIT;" unless args[:no_transaction]
      return sql
    end
    # ------------------------------------------------------- sql_restore_string
    def sql_restore_string( args = {} )
      quoted_attributes = attributes_with_quotes
      sql = "\nINSERT INTO #{self.class.quoted_table_name} " +
      "(#{quoted_column_names.join(', ')}) " +
      "VALUES(#{quoted_attributes.values.join(', ')})"
      unless args[:no_update]
        sql += " ON DUPLICATE KEY UPDATE #{quoted_comma_pair_list(connection, quoted_attributes)}"
      end
      sql += ";\n"
    end
    # -------------------------------------------------------- build_export_tree
    def build_export_tree( tree = {} )
      self.add_to_tree( tree, CREATION_NODE )
      expand_tree_with_relations( tree, self.class.reflections )
      return tree
    end
    # ------------------------------------------------------------- add_to_tree 
    def add_to_tree( tree, type )
      tree[self.class.name] ||= {}
      node = tree[self.class.name][self.id] 
      if node.nil? || node[:type] == EXISTENCE_CHECK_NODE
        tree[self.class.name][self.id] = { :type => type, :object => self }
      end
      return tree
    end
    # ---------------------------------------------------------- build_check_sql
    def build_check_sql
      "IF( NOT EXISTS( SELECT * FROM #{self.class.quoted_table_name} WHERE #{connection.quote_column_name(self.class.primary_key)} = #{quote_value(id)} ) THEN ROLLBACK; END IF;\n"
    end
    # ---------------------------------------- convert_has_many_relations_to_sql
    def expand_tree_with_relations( tree, reflections )
      reflections.each_pair do |key, value|
        case value.macro
        when :has_one
          singleton_method( key ) do |e|
            e.build_export_tree( tree )
          end
        when :has_many, :has_and_belongs_to_many
          send( key ).each{ |x| x.build_export_tree( tree ) }
        when :belongs_to
          singleton_method( key ) do |e|
            e.add_to_tree( tree, EXISTENCE_CHECK_NODE )
          end
        else
          raise "Unhandled reflection: #{value.macro}"
        end
      end
      return tree
    end
    # --------------------------------------------------------- singleton_method
    def singleton_method( key )
      if v = self.send( key )
        yield v
      end
    end
  end
end
