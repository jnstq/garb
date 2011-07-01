module Garb
  class Query
    include Enumerable

    MONTH = 2592000

    def self.define_filter(name, block)
      define_method name do |*args|
        apply_filter(*args, block)
      end
    end

    def self.define_filter_operators(*methods)
      methods.each do |method|
        class_eval <<-CODE
          def #{method}(field, value)
            self.filters << Filter.new(field, :#{method}, value)
          end
        CODE
      end
    end

    attr_reader :parent_klass
    attr_accessor :profile, :start_date, :end_date
    attr_accessor :limit, :offset, :segment, :order # individual, overwritten
    attr_accessor :filters # appended to, may add :segments later for dynamic segments

    def initialize(klass)
      @loaded = false
      @parent_klass = klass
      self.filters = []
      self.start_date = Time.now - MONTH
      self.end_date = Time.now

      klass.filter_definitions.each do |name, block|
        self.class.define_filter(name, block)
      end

      # may add later for dynamic segments
      # klass.segment_definitions.each do |name, segment|
      #   self.class.define_segment(name, segment)
      # end
    end

    def apply_filter(*args, block)
      @profile = extract_profile(args)
      instance_exec(*args, &block)
      self
    end

    def apply_options(options)
      if options.has_key?(:sort)
        # warn
        options[:order] = options[:sort]
      end

      apply_basic_options(options)
      apply_filter_options(options[:filters])

      self
    end

    def apply_basic_options(options)
      [:start_date, :end_date, :order, :limit, :offset, :segment].each do |key|
        self.send("#{key}=".to_sym, options[key]) if options.has_key?(key)
      end
    end

    def apply_filter_options(filter_option)
      [filter_option].flatten.compact.each do |filter|
        filter.each do |key, value|
          field, operator = key, :eql
          field, operator = key.field, key.operator if key.is_a?(SymbolOperator)

          self.filters << Filter.new(field, operator, value)
          # or = false
        end
        # or = true, we have multiple hashes
      end
    end

    def order=(order)
      @order = ReportParameter.new(:order, order)
    end

    def extract_profile(args)
      return args.shift if args.first.is_a?(Management::Profile)
      return args.pop if args.last.is_a?(Management::Profile)
    end

    define_filter_operators :eql, :not_eql, :gt, :gte, :lt, :lte, :matches,
      :does_not_match, :contains, :does_not_contain, :substring, :not_substring

    def loaded?
      @loaded
    end

    def load
      @loaded = true
      @collection = ReportRequest.new(self).response.results
    end

    def collection
      load unless loaded?
      @collection
    end
    alias :to_a :collection

    def each(&block)
      collection.each(&block)
    end

    # if RUBY_19
    #   def or
    #     @or = true
    #   end
    # 
    #   def and
    #     @or = false
    #   end
    # end

    # backwards compatability
    def results(profile=nil, options={})
      self.profile = profile unless profile.nil?
      apply_options(options)
      self
    end

    def total_results
      collection.total_results
    end

    def sampled?
      collection.sampled?
    end

    def metrics
      parent_klass.metrics
    end

    def dimensions
      parent_klass.dimensions
    end

    def segment_id
      segment.nil? ? nil : "gaid::#{segment}"
    end

    def profile_id
      # should we raise here?
      profile.nil? ? nil : Garb.to_ga(profile.id)
    end

    def to_params
      params = {
        'ids' => profile_id,
        'start-date' => Garb.format_time(start_date),
        'end-date' => Garb.format_time(end_date),
        'max-results' => limit,
        'start-index' => offset,
        'segment' => segment_id,
        'filters' => filters.map(&:to_param).join(',') # support AND/OR here
      }

      [metrics, dimensions, order].each do |report_parameter|
        params.merge!(report_parameter.to_params) unless report_parameter.nil?
      end

      params.reject {|k,v| v.nil? || v.to_s.strip.length == 0}
    end
  end
end
