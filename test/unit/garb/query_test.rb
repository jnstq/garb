require 'test_helper'

module Garb
  class QueryTest < MiniTest::Unit::TestCase
    def self.should_define_operators(*operators)
      operators.each do |operator|
        should "create a method for the operator #{operator}" do
          assert_equal true, @query.respond_to?(operator)
        end

        should "add a new filter for #{operator} to the set" do
          Filter.stubs(:new).returns("a filter")
          @query.send(operator, :key, 2000)

          assert_equal ["a filter"], @query.filters
          assert_received(Filter, :new) {|e| e.with(:key, operator, 2000)}
        end
      end
    end

    context "an instance of Query" do
      setup do
        @test_klass = Class.new

        @block = lambda {eql(:key, 1000)}
        @test_klass.stubs(:filter_definitions).returns({:high => @block})
        @query = Query.new(@test_klass)
      end

      should_define_operators :eql, :not_eql, :gt, :gte, :lt, :lte, :matches,
        :does_not_match, :contains, :does_not_contain, :substring, :not_substring

      should "remember the parent class" do
        assert_equal @test_klass, @query.parent_klass
      end

      should "have filter methods to match the parent class" do
        assert_equal true, @query.respond_to?(:high)
      end

      should "have filter methods that call apply with the block" do
        @query.stubs(:apply_filter)
        @query.high('hi')
        assert_received(@query, :apply_filter) {|e| e.with('hi', @block)}
      end

      should "not have results loaded" do
        assert_equal false, @query.loaded?
      end

      context "when applying filters" do
        setup do
          @query.stubs(:eql)
        end

        should "return the query" do
          assert_equal @query, @query.apply_filter(@block)
        end

        should "execute the block" do
          @query.apply_filter(@block)
          assert_received(@query, :eql) {|e| e.with(:key, 1000)}
        end

        should "accept a profile as the first argument" do
          profile = Management::Profile.new
          @query.apply_filter(profile, @block)
          assert_received(@query, :eql)
          assert_equal profile, @query.profile
        end

        should "accept a profile as the last argument before the block" do
          profile = Management::Profile.new
          block = lambda {|count| eql(:key, count)}
          @query.apply_filter(100, profile, block)
          assert_received(@query, :eql) {|e| e.with(:key, 100)}
          assert_equal profile, @query.profile          
        end
      end

      context "when applying options" do
        should "return the query" do
          assert_equal @query, @query.apply_options({})
        end

        should "store the order as a report parameter" do
          @query.apply_options({:order => :page_path})
          assert_equal ReportParameter.new(:order, :page_path), @query.order
        end

        should "replace order" do
          @query.order = :pageviews
          @query.apply_options({:order => :page_path})
          assert_equal ReportParameter.new(:order, :page_path), @query.order          
        end

        should "not replace sort if option is missing" do
          @query.order = :pageviews
          @query.apply_options({})
          assert_equal ReportParameter.new(:order, :pageviews), @query.order
        end

        should "move :sort to :order" do
          @query.apply_options({:sort => :page_path})
          assert_equal ReportParameter.new(:order, :page_path), @query.order
        end

        should "set limit" do
          @query.apply_options({:limit => 100})
          assert_equal 100, @query.limit
        end

        should "replace limit" do
          @query.limit = 200
          @query.apply_options({:limit => 100})
          assert_equal 100, @query.limit
        end

        should "not replace limit if option is missing" do
          @query.limit = 200
          @query.apply_options({})
          assert_equal 200, @query.limit
        end

        should "set offset" do
          @query.apply_options({:offset => 100})
          assert_equal 100, @query.offset
        end

        should "replace offset" do
          @query.offset = 200
          @query.apply_options({:offset => 100})
          assert_equal 100, @query.offset
        end

        should "not replace offset if option is missing" do
          @query.offset = 200
          @query.apply_options({})
          assert_equal 200, @query.offset
        end

        should "set segment" do
          @query.apply_options({:segment => 11})
          assert_equal 11, @query.segment
        end

        should "replace segment" do
          @query.segment = 4
          @query.apply_options({:segment => 11})
          assert_equal 11, @query.segment          
        end

        should "not replace segment if option is missing" do
          @query.segment = 4
          @query.apply_options({})
          assert_equal 4, @query.segment
        end

        context "with dates" do
          setup do
            @now = Time.now
            Time.stubs(:now).returns(@now)
          end

          should "replace start_date" do
            @query.apply_options({:start_date => (@now-2000)})
            assert_equal (@now-2000), @query.start_date
          end

          should "not replace start_date if option is missing" do
            @query.apply_options({})
            assert_equal Garb.format_time(@now-Query::MONTH), Garb.format_time(@query.start_date)
          end

          should "replace end_date" do
            @query.apply_options({:end_date => (@now+2000)})
            assert_equal (@now+2000), @query.end_date
          end

          should "not replace start_date if option is missing" do
            @query.apply_options({})
            assert_equal Garb.format_time(@now), Garb.format_time(@query.end_date)
          end
        end

        # deprecate this stuff
        context "with filters" do
          should "append one filter in a hash with symbol operator key to existing filters" do
            @query.apply_filter_options({:page_path.eql => '/research'})
            assert_equal Filter.new(:page_path, :eql, '/research'), @query.filters.last
          end

          should "append one filter in a hash with symbol key to existing filters" do
            @query.apply_filter_options({:page_path => '/research'})
            assert_equal Filter.new(:page_path, :eql, '/research'), @query.filters.last
          end

          # should "append an array to existing filters"
          # should "append a hash to existing filters"
        end
      end

      context "with options and filters" do
        should "build params" do
          now = Time.now
          @test_klass.extend(Garb::Model)
          @test_klass.metrics :pageviews
          @test_klass.dimensions :page_path

          @query.apply_options({
            :order => :page_path,
            :start_date => now-Query::MONTH,
            :end_date => now,
            :limit => 100,
            :offset => 50,
            :segment => 10
          })

          @query.apply_filter(lambda {eql(:page_path, '/research')})

          @query.profile = stub(:id => "12345")

          params = {
            'ids' => "ga:12345",
            'start-date' => Garb.format_time(now-Query::MONTH),
            'end-date' => Garb.format_time(now),
            'max-results' => 100,
            'start-index' => 50,
            'segment' => "gaid::10",
            'filters' => "ga:pagePath%3D%3D%2Fresearch",
            'metrics' => "ga:pageviews",
            'dimensions' => "ga:pagePath",
            'order' => "ga:pagePath"
          }

          assert_equal params, @query.to_params
        end

        should "not include keys which have no value" do
          now = Time.now
          @test_klass.extend(Garb::Model)
          @test_klass.metrics :pageviews
          @test_klass.dimensions :page_path

          @query.profile = stub(:id => "12345")

          params = {
            'ids' => "ga:12345",
            'start-date' => Garb.format_time(now-Query::MONTH),
            'end-date' => Garb.format_time(now),
            'metrics' => "ga:pageviews",
            'dimensions' => "ga:pagePath"
          }

          assert_equal params, @query.to_params
        end
      end

      should "accepts #results for backwards compatibility" do
        assert_equal @query, @query.results("a profile", {:order => :page_path})
        assert_equal "a profile", @query.profile
        assert_equal ReportParameter.new(:order, :page_path), @query.order
      end

      should "load a collection of results" do
        request = stub(:response => stub(:results => [1,2,3]))
        ReportRequest.stubs(:new).returns(request)
        @query.load
        assert_equal true, @query.loaded?
        assert_received(ReportRequest, :new) {|e| e.with(@query)}
        assert_received(request, :response)
      end

      should "return the collection" do
        request = stub(:response => stub(:results => [1,2,3]))
        ReportRequest.stubs(:new).returns(request)
        @query.load
        assert_equal [1,2,3], @query.collection
        assert_equal [1,2,3], @query.to_a
      end

      context "when enumerating" do
        setup do
          @request = stub(:response => stub(:results => [1,2,3]))
          ReportRequest.stubs(:new).returns(@request)
        end

        should "load if unloaded" do
          @query.each {}
          assert_equal true, @query.loaded?
        end

        should "collect" do
          assert_equal [3,4,5], @query.collect {|i| i+2}
        end

        should "select" do
          assert_equal [2,3], @query.select {|i| i>1}
        end

        should "detect" do
          assert_equal 3, @query.detect {|i| i>2}
        end
      end
    end
  end
end