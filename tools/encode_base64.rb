#!/usr/bin/env ruby

require 'base64'


unless ARGV.length == 1
  puts "Please pass 1 string to encrypt"
  exit (1)
end


puts Base64.encode64(ARGV[0])
