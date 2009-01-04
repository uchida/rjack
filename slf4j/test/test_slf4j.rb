#!/usr/bin/env jruby
#--
# Copyright (c) 2008 David Kellum
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.  
#++

$LOAD_PATH.unshift File.join( File.dirname(__FILE__), "..", "lib" )

require 'slf4j'

# Load jdk14 implementation for testing
require 'slf4j/jdk14'

# Load these only to confirm loading works
require 'slf4j/jcl-over-slf4j'
require 'slf4j/log4j-over-slf4j'

require 'test/unit'

class TestHandler < java.util.logging.Handler
  attr_accessor :count, :last

  def initialize
    reset
  end

  def flush; end
  def close; end
  
  def publish( record )
    @count += 1
    @last = record
  end

  def reset
    @count = 0
    @last = nil
  end
end

class TestSlf4j < Test::Unit::TestCase
  JdkLogger = java.util.logging.Logger
  def setup
    @handler = TestHandler.new
    @jdk_logger = JdkLogger.getLogger "" 
    @jdk_logger.addHandler @handler 
    @jdk_logger.level = java.util.logging.Level::INFO
    @log = SLF4J[ "my.app" ]
  end
  
  def teardown
    @handler.reset
  end

  def test_logger
    assert !@log.trace?
    @log.trace( "not written" )
    assert !@log.debug?
    @log.debug { "also not written" }
    assert @log.info?
    @log.info { "test write info" }
    assert @log.warn?
    @log.warn { "test write warning" }
    assert @log.error?
    @log.error( "test write error" )
    assert @log.fatal?
    @log.fatal { "test write fatal --> error" }
    assert_equal( 4, @handler.count )
  end

  def test_circular_ban
    assert_raise( RuntimeError ) do
      require 'slf4j/jul-to-slf4j'
    end
  end

end