require 'test_helper.rb'

class ActiveRecordSqlExporterTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "Exporting simple model" do
    obj = Simple.create( name: "A Test" )
    expected = "BEGIN;\nINSERT INTO `simples` (`id`,`name`) VALUES (#{obj.id},'A Test') ON DUPLICATE KEY UPDATE `id`=#{obj.id},`name`='A Test';\nCOMMIT;"
    assert_equal( expected, obj.to_backup_sql )
  end
  test "Exporting model with has_many" do 
    d = Department.create!( name: "Department of Change" )
    d.employees.create!( name: "Good Employee" )
    assert( d.to_backup_sql )
  end
  test "Exporting model with polymorphic belongs to" do
    p = Project.create!( name: "Document Conversion",
        owner: Department.create!(name: "Public Works" ) )
    puts p.to_backup_sql
  end
  test "Exporting model with dependent nullify" do
    proj = Project.create!( name: "Public Works" )
    t1 = Task.create!( name: "Test Task 1", project: proj )
    t2 = Task.create!( name: "Test Task 2", project: proj )
    assert( proj.tasks.any? )
    assert( proj.to_backup_sql =~ /UPDATE `tasks` SET .*`project_id`=#{proj.id}.* WHERE `id` = #{t1.id}/, proj.to_backup_sql )
    assert( proj.to_backup_sql =~ /UPDATE `tasks` SET .*`project_id`=#{proj.id}.* WHERE `id` = #{t2.id}/, proj.to_backup_sql )
  end
end
