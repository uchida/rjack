#!/usr/bin/env jruby
#--
# Copyright 2008 David Kellum
#
# Licensed under the Apache License, Version 2.0 (the "License"); you
# may not use this file except in compliance with the License.  You
# may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.  See the License for the specific language governing
# permissions and limitations under the License.
#++

TEST_DIR = File.dirname(__FILE__)

$LOAD_PATH.unshift File.join( TEST_DIR, "..", "lib" )

require 'jetty'
require 'logback'
require 'net/http'
require 'test/unit'

Logback.configure do
  Logback.root.add_appender( Logback::ConsoleAppender.new )
  Logback.root.level = Logback::INFO
  Logback[ 'org.mortbay' ].level = Logback::WARN
end

class TestJetty < Test::Unit::TestCase

  def test_static_context
    factory = Jetty::ServerFactory.new
    factory.max_threads = 1
    factory.static_contexts[ '/' ] = TEST_DIR
    server = factory.create
    server.start
    port = server.connectors.first.local_port
    test_text = Net::HTTP.get( 'localhost', '/test.txt', port )
    assert_equal( File.read( File.join( TEST_DIR, 'test.txt' ) ), test_text )
    server.stop
  end

  import 'org.mortbay.jetty.handler.AbstractHandler'
  class TestHandler < AbstractHandler
    TEST_TEXT = 'test handler text'

    def handle( target, request, response, dispatch )
      response.content_type = "text/plain"
      response.writer.write( TEST_TEXT )
      request.handled = true
    end
  end
  

  def test_custom_handler
    factory = Jetty::ServerFactory.new
    factory.max_threads = 1
    def factory.create_pre_handlers
      super << TestHandler.new
    end
    server = factory.create
    server.start
    port = server.connectors.first.local_port
    assert_equal( TestHandler::TEST_TEXT, 
                  Net::HTTP.get( 'localhost', '/whatever', port ) )
    server.stop
  end


  import 'javax.servlet.http.HttpServlet'
  class TestServlet < HttpServlet
    def initialize( text )
      super()
      @text = text
    end

    def doGet( request, response )
      response.content_type = "text/plain"
      response.writer.write( @text )
    end
  end

  def test_servlet_handler
    factory = Jetty::ServerFactory.new
    factory.max_threads = 1
    factory.add_servlets( '/', 
                          { '/test'  => TestServlet.new( 'resp-test' ),
                            '/other' => TestServlet.new( 'resp-other' ), } )
    factory.add_servlets( '/', { '/one' => TestServlet.new( 'resp-one' ) } )
    server = factory.create
    server.start
    port = server.connectors.first.local_port
    assert_equal( 'resp-test',
                  Net::HTTP.get( 'localhost', '/test', port ) )
    assert_equal( 'resp-other', 
                  Net::HTTP.get( 'localhost', '/other', port ) )
    assert_equal( 'resp-one',
                  Net::HTTP.get( 'localhost', '/one', port ) )
    
    response = Net::HTTP.get_response( 'localhost', '/', port )
    assert( response.is_a?( Net::HTTPNotFound ) )

    server.stop
  end

  
end
