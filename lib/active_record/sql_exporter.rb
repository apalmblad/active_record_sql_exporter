# encoding: UTF-8
module ActiveRecord::SqlExporter
  class NestedException < ArgumentError
    attr_accessor :old_exception, :klass
    def initialize( old_exception, klass, key )
      @old_exception = old_exception
      @klass = klass
      @key = key
    end

    # --------------------------------------------------------------------- to_s
    def to_s
      "Unexpected error on #{@klass}.#{@key} / #{@old_exception.to_s}"
    end
  end
  # ------------------------------------------------------------------ included?
  def included?( klass )
    klass.include( InstanceMethods )
    klass.extend( ClassMethods )
  end
  ##############################################################################
  # FileWriter
  ##############################################################################
  class FileWriter
    # --------------------------------------------------------------- initialize
    def initialize( file )
      @file = file
    end
    # ------------------------------------------------------------------------ +
    def +( s )
      @file.write( s )
      return self
    end
  end

  module ClassMethods
    # ---------------------------------------------------------- build_check_sql
    def build_check_sql( id )
      "IF( NOT EXISTS( SELECT * FROM #{quoted_table_name} WHERE #{self.class.connection.quote_column_name(primary_key)} = #{quote_value(id)} ) THEN ROLLBACK; END IF;\n"
    end
  end

  module InstanceMethods
    CREATION_NODE = 1
    EXISTENCE_CHECK_NODE = 2
    UPDATE_NODE = 3
    # --------------------- pretend_to_sql( args = {}, classes_to_ignore = [] ) 
    def print_relation_tree( args = {}, classes_to_ignore = [] ) 
      tree = {}
      _print_relation( tree, classes_to_ignore )
      return if classes_to_ignore.include?( self.class )
    end
    # ------------------------------------------------------------------- to_sql
    def to_backup_sql( args = {}, classes_to_ignore = [] )
      tree = {}
      build_export_tree( tree, classes_to_ignore )
      sql = args[:file] ? ActiveRecord::SqlExporter::FileWriter.new( args[:file] ) : ''
      unless args[:no_transaction]
        sql += "BEGIN;"
      end
      tree.keys.each do |klass|
        tree[klass].keys.each do |id|
          node = tree[klass][id]
          begin
            if node[:type] == EXISTENCE_CHECK_NODE
              sql += klass.constantize.build_check_sql( id )
            elsif node[:type] == CREATION_NODE
              object = klass.constantize.find( id )
              sql += object.sql_restore_string
            elsif node[:type] == UPDATE_NODE
              object = klass.constantize.find( id )
              sql += object.update_sql_string( node[:key] )
            end
          rescue Encoding::UndefinedConversionError
            raise "Error with encoding of #{object.inspect}"
          end
        end
      end
      sql += "COMMIT;" unless args[:no_transaction]
      return sql
    end
################################################################################
    protected
################################################################################
    # -------------------------------------------------------- update_sql_string
    def update_sql_string( key_name )
      data = []
      self.class.columns.map do |x|
        next if x.primary
        data << "#{self.class.connection.quote_column_name( x.name )}=#{self.class.connection.quote( read_attribute(x.name))}"
      end
      "UPDATE #{self.class.quoted_table_name} SET #{data.join(',')} WHERE #{self.class.connection.quote_column_name(self.class.primary_key)} = #{quote_value(id)};\n"
    end
    # ------------------------------------------------------- sql_restore_string
    def sql_restore_string( args = {} )
      columns = self.class.columns.map do |x|
        self.class.connection.quote_column_name( x.name )
      end
      values = self.class.columns.map do |x|
        self.class.connection.quote( read_attribute( x.name ) )
      end

      sql = "\nINSERT INTO #{self.class.quoted_table_name} (#{columns.join(',')}) VALUES (#{values.join(',')})"
      unless args[:no_update]
        pairs = []
        columns.each_with_index do |c,i|
          pairs << "#{c}=#{values[i]}"
        end
        sql += " ON DUPLICATE KEY UPDATE #{pairs.join(',')}"
      end
      sql += ";\n"
      return sql
    end
    # -------------------------------------------------------- build_export_tree
    def build_export_tree( tree = {}, classes_to_ignore = [] )
      return if classes_to_ignore.include?( self.class )
      if tree[self.class.name].nil? || ( tree[self.class.name] && ( tree[self.class.name][id].nil? || tree[self.class.name][id][:type] == EXISTENCE_CHECK_NODE ) )
        self.add_to_tree( tree, CREATION_NODE )
        expand_tree_with_relations( tree, self.class.reflections, classes_to_ignore )
      end
      return tree
    end
    # ------------------------------------------------------------- add_to_tree 
    def add_to_tree( tree, type, options = {} )
      tree[self.class.name] ||= {}
      node = tree[self.class.name][self.id] 
      if node.nil? || node[:type] == EXISTENCE_CHECK_NODE
        options[:type] = type
        tree[self.class.name][self.id] = options
      end
      return tree
    end
    # ---------------------------------------------------------- build_check_sql
    def build_check_sql
      "IF( NOT EXISTS( SELECT * FROM #{self.class.quoted_table_name} WHERE #{self.class.connection.quote_column_name(self.class.primary_key)} = #{quote_value(id)} ) THEN ROLLBACK; END IF;\n"
    end
    # ---------------------------------------- convert_has_many_relations_to_sql
    def expand_tree_with_relations( tree, reflections, classes_to_ignore )
      reflections.each_pair do |key, value|
        next if value.options[:dependent] && ![:destroy, :nullify].include?( value.options[:dependent] )
        if value.options[:polymorphic]
          next if classes_to_ignore.include?( send( key ).class )
        else
          begin
            next if classes_to_ignore.include?( value.klass )
          rescue
            raise "Problem in a #{self.class.name} with #{key} = #{value}"
          end
        end
        case value.macro
        when :has_one
          begin
            singleton_method( key ) do |e|
              e.build_export_tree( tree, classes_to_ignore )
            end
          rescue NestedException => ex
            raise NestedException.new( ex.old_exception, "#{self.class.name}.#{ex.klass}", key )
          rescue Exception => ex
            raise NestedException.new( ex, self.class.name, key )
          end
        when :has_many, :has_and_belongs_to_many
          begin
            records = send( key )
            if value.options[:dependent] == :nullify
              records.each do |record|
                record.add_to_tree( tree, UPDATE_NODE, key: value.association_primary_key )
              end
            else
              records.each{ |x| x.build_export_tree( tree, classes_to_ignore ) }
            end
          rescue NestedException => ex
            raise NestedException.new( ex.old_exception, "#{self.class.name}.#{ex.klass}", key )
          rescue Exception => ex
            raise ex
            raise NestedException.new( ex, self.class.name, key )
          end
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
    # ----------------------------------------------------------- print_relation
    def _print_relation( tree, classes_to_ignore, indent_depth = 0 )
      if tree[self.class.name].nil? || ( tree[self.class.name] && ( tree[self.class.name][id].nil? || tree[self.class.name][id][:type] == EXISTENCE_CHECK_NODE ) )
        puts "%s%s - %d" % ["\t" * indent_depth, self.class.name, self.id]
        self.add_to_tree( tree, CREATION_NODE )
        _print_reflection_relations( tree, self.class.reflections, classes_to_ignore, indent_depth + 1 )
      end
    end
    # ---------------------------------------- convert_has_many_relations_to_sql
    def _print_reflection_relations( tree, reflections, classes_to_ignore, indent_level = 1 )
      reflections.each_pair do |key, value|
        next if value.options[:dependent] && ![:destroy, :nullify].include?( value.options[:dependent] )
        if value.options[:polymorphic]
          next if classes_to_ignore.include?( send( key ).class )
        else
          begin
            next if classes_to_ignore.include?( value.klass )
          rescue
            raise "Problem in a #{self.class.name} with #{key} = #{value}"
          end
        end
        case value.macro
        when :has_one
          singleton_method( key ) do |e|
            e._print_relation( tree, classes_to_ignore, indent_level )
          end
        when :has_many, :has_and_belongs_to_many
          records = send( key )
          if value.options[:dependent] == :nullify
            records.each do |record|
              record.add_to_tree( tree, UPDATE_NODE, key: value.primary_key_name )
              puts "%s%s [UPDATE] - %d" % ["\t" * indent_level, record.class.name, record.id]
            end
          else
            records.each do |x|
              x._print_relation( tree, classes_to_ignore, indent_level )
            end
          end
        when :belongs_to
        else
          raise "Unhandled reflection: #{value.macro}"
        end
      end
    end
    # --------------------------------------------------------- singleton_method
    def singleton_method( key )
      if v = self.send( key )
        yield v
      end
    end
  end
end
