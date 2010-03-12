# Include hook code here
require 'active_record/sql_exporter'
ActiveRecord::Base.send( :include, ActiveRecord::SqlExporter::InstanceMethods )
