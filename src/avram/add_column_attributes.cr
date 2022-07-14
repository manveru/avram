# This module creates methods for each column in a model that map
# to an `Avram::Attribute` as well as methods that fill those attributes
# with values that comes from params.
module Avram::AddColumnAttributes
  # :nodoc:
  macro add_column_attributes(attributes)
    {% for attribute in attributes %}
      {% COLUMN_ATTRIBUTES << attribute %}
    {% end %}

    private def extract_changes_from_params
      permitted_params.each do |key, value|
        {% for attribute in attributes %}
          {% if attribute[:type].is_a?(Generic) %}
            set_{{ attribute[:name] }}_from_param(value.as(Array(String))) if key == {{ attribute[:name].stringify }}
          {% else %}
            set_{{ attribute[:name] }}_from_param(value.as(String)) if key == {{ attribute[:name].stringify }}
          {% end %}
        {% end %}
      end
    end

    def permitted_params
      single_values = @params.nested(self.class.param_key).reject {|k,v| k.ends_with?("[]")}
      array_values = @params.nested_arrays?(self.class.param_key) || {} of String => Array(String)
      new_params = single_values.merge(array_values)
      new_params.select(@@permitted_param_keys)
    end

    {% for attribute in attributes %}
      @_{{ attribute[:name] }} : Avram::Attribute({{ attribute[:type] }})?

      def {{ attribute[:name] }}
        _{{ attribute[:name] }}
      end

      def {{ attribute[:name] }}=(_value)
        \{% raise <<-ERROR
          Can't set an attribute value with '{{attribute[:name]}} = '

          Try this...

            ▸ Use '.value' to set the value: '{{attribute[:name]}}.value = '

          ERROR
          %}
      end

      private def _{{ attribute[:name] }}
        record_value = @record.try(&.{{ attribute[:name] }})
        value = record_value.nil? ? default_value_for_{{ attribute[:name] }} : record_value

        @_{{ attribute[:name] }} ||= Avram::Attribute({{ attribute[:type] }}).new(
          name: :{{ attribute[:name].id }},
          param: permitted_params["{{ attribute[:name] }}"]?,
          value: value,
          param_key: self.class.param_key)
      end

      private def default_value_for_{{ attribute[:name] }}
        {% if attribute[:value] || attribute[:value] == false %}
          parse_result = {{ attribute[:type] }}.adapter.parse({{ attribute[:value] }})
          if parse_result.is_a? Avram::Type::SuccessfulCast
            parse_result.value.as({{ attribute[:type] }})
          else
            nil
          end
        {% else %}
          nil
        {% end %}
      end

      {% if attribute[:type].is_a?(Generic) %}
      def set_{{ attribute[:name] }}_from_param(_value : Array(String))
        parse_result = {{ attribute[:type] }}.adapter.parse(_value)

        if parse_result.is_a? Avram::Type::SuccessfulCast
          {{ attribute[:name] }}.value = parse_result.value.as({{ attribute[:type] }})
        else
          {{ attribute[:name] }}.add_error "is invalid"
        end
      end
      {% else %}
      def set_{{ attribute[:name] }}_from_param(_value)
        # In nilable types, `nil` is ok, and non-nilable types we will get the
        # "is required" error.
        if _value.blank?
          {{ attribute[:name] }}.value = nil
          return
        end

        parse_result = {{ attribute[:type] }}.adapter.parse(_value)

        if parse_result.is_a? Avram::Type::SuccessfulCast
          {{ attribute[:name] }}.value = parse_result.value.as({{ attribute[:type] }})
        else
          {{ attribute[:name] }}.add_error "is invalid"
        end
      end
      {% end %}
    {% end %}

    def attributes
      column_attributes + super
    end

    private def column_attributes
      [
        {% for attribute in attributes %}
          {{ attribute[:name] }},
        {% end %}
      ]
    end

    def required_attributes
      Tuple.new(
        {% for attribute in attributes %}
          {% if !attribute[:nilable] && !attribute[:autogenerated] %}
            {{ attribute[:name] }},
          {% end %}
        {% end %}
      )
    end
  end
end
