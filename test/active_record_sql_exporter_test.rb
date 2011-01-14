require 'test_helper.rb'

class ActiveRecordSqlExporterTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "Exporting simple model" do
    obj = Simple.create( :name => "A Test" )
    expected = "BEGIN;\nINSERT INTO `simples` (`name`, `id`) VALUES('A Test', #{obj.id}) ON DUPLICATE KEY UPDATE `name` = 'A Test', `id` = #{obj.id};\nCOMMIT;"
    assert_equal( expected, obj.to_sql )
  end
  test "Exporting model with has_many" do 
    d = Department.create!( :name => "Department of Change" )
    d.employees.create!( :name => "Good Employee" )
    raise d.to_sql
  end
  test "Exporiting model with polymorphic belongs to" do
    p = Project.create!( :name => "Document Conversion",
        :owner => Department.create!(:name => "Public Works" ) )
    puts p.to_sql
  end
end
