#!/usr/bin/env ruby

SimpleCov.minimum_coverage 95

SimpleCov.start do
  add_filter '/spec/'
  add_group 'lib', 'lib'
end