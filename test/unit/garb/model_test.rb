require 'test_helper'

class ResultKlass
  def initialize(attrs)
  end
end

module Garb
  class ModelTest < MiniTest::Unit::TestCase
    context "A class extended with Garb::Model" do
      setup do
        @test_model = Class.new
        @test_model.extend(Garb::Model)
      end

      teardown do
        
      end

      # public API
      should "be able to define metrics" do
        report_parameter = stub(:<<)
        ReportParameter.stubs(:new).returns(report_parameter)

        @test_model.metrics :visits, :pageviews

        assert_received(ReportParameter, :new) {|e| e.with(:metrics)}
        assert_received(report_parameter, :<<) {|e| e.with([:visits, :pageviews])}
      end

      should "be able to define dimensions" do
        report_parameter = stub(:<<)
        ReportParameter.stubs(:new).returns(report_parameter)

        @test_model.dimensions :page_path, :event_category

        assert_received(ReportParameter, :new) {|e| e.with(:dimensions)}
        assert_received(report_parameter, :<<) {|e| e.with([:page_path, :event_category])}
      end

      should "be able to se the instance klass" do
        @test_model.set_instance_klass ResultKlass
        assert_equal ResultKlass, @test_model.instance_klass
      end

      should "have an empty hash for filter definitions" do
        assert_equal({}, @test_model.filter_definitions)
      end

      context "when defining filters" do
        should "create a class method" do
          @test_model.filter :high, lambda {}
          assert_equal true, @test_model.respond_to?(:high)
        end
      end

      context "with filters defined" do
        should "return a Query instance" do
          block = lambda {}
          @test_model.filter :high, block
          query = stub(:apply_filter => "a query")
          Query.stubs(:new).returns(query)

          assert_equal "a query", @test_model.high("arrrg")
          assert_received(Query, :new) {|e| e.with(@test_model)}
          assert_received(query, :apply_filter) {|e| e.with("arrrg", block)}
        end

        should "have the filter stored in an hash" do
          block = lambda {}
          @test_model.filter :high, block

          assert_equal block, @test_model.filter_definitions[:high]
        end
      end

      should "proxy results to a new query" do
        options = {}
        profile = stub
        query = stub(:results => "a query")
        Query.stubs(:new).returns(query)

        assert_equal "a query", @test_model.results(profile, options)
        assert_received(Query, :new) {|e| e.with(@test_model)}
        assert_received(query, :results) {|e| e.with(profile, options)}
      end
    end
  end
end
