#!/usr/bin/env ruby

SimpleCov.minimum_coverage 100

SimpleCov.start do
  add_filter '/spec/'
  add_group 'lib', 'lib'
end
