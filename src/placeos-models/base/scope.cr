module PlaceOS::Model::Scope
  macro included
        macro scope(name, &block)
            {% verbatim do %}
              {% parameters = "" %}
              {% for arg, idx in block.args %}
                {% parameters = parameters + "*" if (block.splat_index && idx == block.splat_index) %}
                {% parameters = parameters + "#{arg}" %}
                {% parameters = parameters + ", " unless (idx == block.args.size - 1) %}
              {% end %}
              {% parameters = parameters.id %}

              def self.{{name.id}}({{parameters}})
                query.{{name.id}}({{parameters}})
              end

              module ::PgORM::Query::Methods(T)
                def {{name.id}}({{parameters}})
                  {{yield}}
                end
              end
            {% end %}
          end
    end
end
