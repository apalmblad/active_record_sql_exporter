ActiveRecord::Base.configurations = {
  'active_record_schema_exporter' => {
    :adapter  => 'mysql',
    :username => 'root',
    :encoding => 'utf8',
    :database => 'active_record_sql_exporter_test',
  }
}

ActiveRecord::Base.establish_connection 'active_record_schema_exporter'

ActiveRecord::Schema.define do
  create_table :departments, :force => true do |t|
    t.string :name
  end
  create_table :budgets, :force => true do |t|
    t.integer :amount
    t.integer :department_id
  end
  create_table :employees, :force => true do |t|
    t.integer :department_id
    t.string :name
    t.date  :started
  end
  create_table :simples, :force => true do |t|
    t.string :name
  end
end

class Employee < ActiveRecord::Base
  belongs_to :department
end

class Department < ActiveRecord::Base
  has_many :employees
  has_one :budget
  belongs_to :manager, :class_name => 'Employee'
end

class Budget < ActiveRecord::Base
  belongs_to :department 
end

class Simple < ActiveRecord::Base
end
