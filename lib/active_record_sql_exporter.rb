# ActiveRecordSqlExporter
require 'active_record/sql_exporter'
ActiveRecord::Base.send( :include, ActiveRecord::SqlExporter::InstanceMethods )
ActiveRecord::Base.send( :extend, ActiveRecord::SqlExporter::ClassMethods )
