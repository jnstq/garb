module Garb
  module Model
    MONTH = 2592000
    URL = "https://www.google.com/analytics/feeds/data"

    def self.extended(base)
      ProfileReports.add_report_method(base)
    end

    def metrics(*fields)
      @metrics ||= ReportParameter.new(:metrics)
      @metrics << fields
    end

    def dimensions(*fields)
      @dimensions ||= ReportParameter.new(:dimensions)
      @dimensions << fields
    end

    def set_instance_klass(klass)
      @instance_klass = klass
    end

    def filter_definitions
      @filter_definitions ||= {}
    end

    def filter(name, block)
      filter_definitions[name] = block
      metaclass = (class << self; self; end)
      metaclass.instance_eval {define_method(name) {|*args| Query.new(self).apply_filter(*args, block)}}
    end

    def instance_klass
      @instance_klass || OpenStruct
    end

    def results(profile, options = {})
      Query.new(self).results(profile, options)
    end
  end
end