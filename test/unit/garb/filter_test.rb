require 'test_helper'

module Garb
  class FilterTest < MiniTest::Unit::TestCase
    context "an instance of Filter" do
      setup do
        @filter = Filter.new(:page_path, :eql, "/research")
      end

      should "have an operator" do
        assert_equal :eql, @filter.operator
      end

      should "have an operator for google" do
        assert_equal URI.encode('==', /[=<>]/), @filter.google_operator
      end

      should "have a field" do
        assert_equal :page_path, @filter.field
      end

      should "have a field for google" do
        assert_equal Garb.to_ga(:page_path), @filter.google_field
      end

      should "have a value" do
        assert_equal "/research", @filter.value
      end

      should "have an escaped value" do
        assert_equal "%2Fresearch", @filter.escaped_value
      end

      should "escape comma, semicolon, and backslash in values" do
        filter = Filter.new(:eql, :url, 'this;that,thing\other')
        assert_equal 'this%5C%3Bthat%5C%2Cthing%5C%5Cother', filter.escaped_value
      end

      should "turn into params" do
        assert_equal "ga:pagePath%3D%3D%2Fresearch", @filter.to_param
      end
    end
  end
end