Gem::Specification.new do |s|
  s.name        = "active_record_sql_exporter"
  s.version     =  "0.2.0"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Palmblad"]
  s.email       = ["Adam Palmblad"]
  s.homepage    = "http://github.com/apalmblad/active_record_sql_exporter"
  s.summary     = "Export active record objects to raw sql."
  s.description = "Quickly export an active record object to raw sql, useful for restoring partial data from a backup"

  s.required_rubygems_version = ">= 1.3.6"
  s.add_dependency( "rails", "<4")
  s.add_development_dependency( "mysql" )

  s.files        = Dir.glob("lib/**/*") + %w(MIT-LICENSE README)
  s.require_path = 'lib'
end
