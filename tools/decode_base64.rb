#!/usr/bin/env ruby

require 'base64'


unless ARGV.length == 1
  puts "Please pass 1 string to decrypt"
  exit (1)
end


puts Base64.decode64(ARGV[0])
