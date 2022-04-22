require "../src/ext/*"

require "placeos-log-backend"

::Log.setup("*", backend: PlaceOS::LogBackend.log_backend, level: :trace)

require "spec"
require "random"
require "rethinkdb-orm"
require "timecop"

# Generators for Engine models
require "./generator"

# Configure DB
db_name = "test"

Spec.before_suite do
  RethinkORM.configure do |settings|
    settings.db = db_name
  end
end

# Clear test tables on exit
Spec.after_suite do
  RethinkORM::Connection.raw do |q|
    q.db(db_name).table_list.for_each do |t|
      q.db(db_name).table(t).delete
    end
  end
end

# Spec Macros
#################################################################

macro test_round_trip(klass)
  it "satisfies the round-trip property" do
    model = Generator.{{ klass.stringify.split("::").last.underscore.id }}.save!

    json = model.to_json
    {{ klass }}.from_trusted_json(json).to_json.should eq(json)
  ensure
    model.try &.delete
  end
end

# Models
#################################################################

# Pretty prints document errors
def inspect_error(error : RethinkORM::Error::DocumentInvalid)
  message = error.model.errors.join('\n') do |e|
    "#{e.field} #{e.message}"
  end

  puts message
end

# Helper to check if string is encrypted
def is_encrypted?(string : String)
  string.starts_with? '\e'
end
