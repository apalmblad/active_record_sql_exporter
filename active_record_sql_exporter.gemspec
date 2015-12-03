Gem::Specification.new do |s|
  s.name        = "active_record_sql_exporter"
  s.licenses = ['MIT']
  s.version     =  "0.2.5"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Palmblad"]
  s.email       = ["apalmblad@gmail.com"]
  s.homepage    = "http://github.com/apalmblad/active_record_sql_exporter"
  s.summary     = "Export active record objects to raw sql."
  s.description = "Quickly export an active record object to raw sql, useful for restoring partial data from a backup"

  s.required_rubygems_version = ">= 1.3.6"
  s.add_dependency( "rails", "<5")
  #s.add_development_dependency( "mysql" )

  s.files        = Dir.glob("lib/**/*") + %w(MIT-LICENSE README)
  s.require_path = 'lib'
end
