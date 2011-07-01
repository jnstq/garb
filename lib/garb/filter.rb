module Garb
  class Filter
    attr_accessor :field, :operator, :value

    OPERATORS = {
      :eql => '==',
      :not_eql => '!=',
      :gt => '>',
      :gte => '>=',
      :lt => '<',
      :lte => '<=',
      :matches => '==',
      :does_not_match => '!=',
      :contains => '=~',
      :does_not_contain => '!~',
      :substring => '=@',
      :not_substring => '!@',
      :desc => '-',
      :descending => '-'
    }

    def initialize(field, operator, value)
      self.field = field
      self.operator = operator
      self.value = value
    end

    def google_field
      Garb.to_ga(field)
    end

    def google_operator
      URI.encode(OPERATORS[operator], /[=<>]/)
    end

    def escaped_value
      CGI::escape(value.to_s.gsub(/([,;\\])/) {|c| '\\'+c})
    end

    def to_param
      "#{google_field}#{google_operator}#{escaped_value}"
    end

    def ==(other)
      field == other.field && operator == other.operator && value == other.value
    end
  end
end