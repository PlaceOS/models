require "../src/ext/*"

require "placeos-log-backend"

::Log.setup("*", :trace)

Spec.before_suite do
  ::Log.setup("*", :trace)
end

require "spec"
require "random"
require "pg-orm"
require "timecop"

# Generators for Engine models
require "./generator"

PgORM::Database.parse(ENV["PG_DATABASE_URL"])

# Clear test tables on exit
Spec.after_suite do
  {% for model in PlaceOS::Model::ModelBase.subclasses %}
    {{model.id}}.clear
  {% end %}
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
def inspect_error(error : PgORM::Error::RecordInvalid)
  message = error.model.errors.join('\n') do |e|
    "#{e.field} #{e.message}"
  end

  puts message
end

# Helper to check if string is encrypted
def is_encrypted?(string : String)
  string.starts_with? '\e'
end
