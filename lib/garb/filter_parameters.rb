module Garb
  class FilterParameters
    attr_accessor :parameters

    def initialize(parameters)
      self.parameters = [parameters].flatten.compact
    end

    def to_params
      value = self.parameters.map do |param|
        param.map do |k,v|
          next unless k.is_a?(SymbolOperator)
          escaped_v = v.to_s.gsub(/([,;\\])/) {|c| '\\'+c}
          "#{URI.encode(k.to_google_analytics, /[=<>]/)}#{CGI::escape(escaped_v)}"
        end.join('%3B') # Hash AND (no duplicate keys), escape char for ';' fixes oauth
      end.join(',') # Array OR

      value.empty? ? {} : {'filters' => value}
    end
  end
end
