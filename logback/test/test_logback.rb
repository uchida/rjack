#!/usr/bin/env jruby
#.hashdot.profile += jruby-shortlived

#--
# Copyright (c) 2008-2015 David Kellum
#
# rjack-logback is free software: you can redistribute it and/or
# modify it under the terms of either of following licenses:
#
#   GNU Lesser General Public License v3 or later
#   Eclipse Public License v1.0
#
# rjack-logback is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#++

require 'rubygems'
require 'bundler/setup'

require 'rjack-slf4j'
require 'rjack-slf4j/jul-to-slf4j'

require 'rjack-logback'

require 'rjack-slf4j/mdc'

# Test load works
require 'rjack-logback/access'

require 'minitest/unit'
require 'minitest/autorun'

class TestAppender
  import 'ch.qos.logback.core.Appender'
  include Appender

  attr_reader :count, :last
  attr_writer :layout

  def initialize
    reset
  end

  def doAppend( event )
    @count += 1
    @last = event
    @last = @layout.nil? ? event : @layout.doLayout( event )
  end

  def start; end
  def stop; end

  def reset
    @count = 0
    @last = nil
    @layout = nil
  end
end

class TestLevelSet < MiniTest::Unit::TestCase
  include RJack

  def setup
    @appender = TestAppender.new
    Logback.configure do
      Logback.root.add_appender( @appender )
    end
    @log = SLF4J[ "my.app" ]
  end

  def teardown
    @appender.reset()
  end

  def test_below_level
    Logback.root.level = Logback::ERROR
    assert( ! @log.debug? )
    @log.debug( "not logged" )
    @log.debug { "also not logged" }
    assert_equal( 0, @appender.count )
  end

  def test_off
    Logback.root.level = Logback::OFF
    assert( ! @log.debug? )
    @log.debug( "not logged" )
    @log.warn { "also not logged" }
    @log.error { "again; not logged"}
    assert_equal( 0, @appender.count )
  end

  def test_above_level
    Logback.root.level = Logback::TRACE
    assert( @log.trace? )
    @log.trace( "logged" )
    assert_equal( 1, @appender.count )
    assert_equal( Logback::TRACE, @appender.last.level )
    assert_equal( "logged", @appender.last.message )
  end

  def test_override_level
    Logback.root.level = Logback::ERROR
    Logback[ "my" ].level = Logback::WARN
    assert( @log.warn? )
    @log.warn( "override" )
    assert_equal( Logback::WARN, @appender.last.level )
    assert_equal( 1, @appender.count )

    # Unset override
    Logback[ "my" ].level = nil
    assert( ! @log.warn? )
  end

  def test_with_level
    Logback.root.level = Logback::INFO
    assert( ! @log.debug? )
    Logback.root.with_level( Logback::DEBUG ) do
      assert( @log.debug? )
    end
    assert( ! @log.debug? )
  end

   def test_symbol_level
     Logback.root.level = :trace
     assert( @log.trace? )
     Logback.root.level = :info
     assert( ! @log.debug? )
   end

end

class TestJULPropagator < MiniTest::Unit::TestCase
  include RJack

  def test_jul_propagator
    SLF4J::JUL.replace_root_handlers

    appender = TestAppender.new
    Logback.configure do |ctx|
      ctx.add_listener( Logback::LevelChangePropagator.new )
      Logback.root.add_appender( appender )
      Logback.root.level = Logback::WARN
      Logback[ "alt" ].level = Logback::DEBUG
    end

    assert( ! SLF4J::JUL[ "other"   ].loggable?( SLF4J::JUL::INFO ) )
    assert(   SLF4J::JUL[ "alt.sub" ].loggable?( SLF4J::JUL::INFO ) )

    SLF4J::JUL[ "other"   ].info( "shouldn't" )
    assert_equal( 0, appender.count )
    SLF4J::JUL[ "alt.sub" ].info( "should" )
    assert_equal( 1, appender.count )
  end

end

class TestConfigure < MiniTest::Unit::TestCase
  include RJack

  def test_file_appender_config
    log_file = "./test_appends.test_file_appender.log"

    Logback.configure do
      appender = Logback::FileAppender.new( log_file, false ) do |a|
        a.layout = Logback::PatternLayout.new( "%level-%msg" )
        a.encoding = "ISO-8859-1"
      end
      Logback.root.add_appender( appender )
    end
    log = SLF4J[ self.class.name ]
    log.debug( "write to file" )
    assert( File.file?( log_file ) )
    assert( File.stat( log_file ).size > 0 )
    assert_equal( 1, File.delete( log_file ) )
  end

  def test_pattern_config
    appender = TestAppender.new
    Logback.configure do
      appender.layout = Logback::PatternLayout.new( "%level-%msg" )
      Logback.root.add_appender( appender )
    end

    log = SLF4J[ self.class.name ]
    log.info( "message" )
    assert_equal( 1, appender.count )
    assert_equal( "INFO-message", appender.last )
  end

  def test_console_config
    log_name = "#{self.class.name}.test_console_config"
    appender = TestAppender.new
    Logback.configure do
      console = Logback::ConsoleAppender.new do |a|
        a.encoding = "UTF-8"
        a.target = "System.out"
      end
      Logback.root.add_appender( console )
      Logback[ log_name ].add_appender( appender )
    end

    Logback[ log_name ].level = Logback::DEBUG
    Logback[ log_name ].additive = false
    log = SLF4J[ log_name ]
    log.debug( "test write to console" )
    assert_equal( 1, appender.count )
  end

  def test_config_console
    Logback.config_console( :level => :info, :stderr => true )
    log = SLF4J[ self.class.name ]
    assert( log.info? )
    assert( ! log.debug? )
  end

  def test_config_console_mdc
    Logback.config_console( :mdc => [ :key1, :key2 ], :mdc_width => 11 )
    log = SLF4J[ self.class ]
    log.info "without"
    SLF4J::MDC[ :key1 ] = "val1"
    log.info "with 1"
    SLF4J::MDC[ :key2 ] = "val2"
    log.info "with 2"
  end

end
