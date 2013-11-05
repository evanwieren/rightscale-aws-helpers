#!/usr/bin/env ruby

require 'json'

begin
  #puts ARGV[0]
  f=File.open(ARGV[0], 'r')

  json_inputs = f.read()

  server_inputs = JSON.parse(json_inputs)

  server_inputs.keys.each do |key|
    puts "#{key} = #{server_inputs[key]}"
  end

  #parameters = {}
  #junk = server_inputs['parameters']
  #puts "junk is of type #{junk.class}"
  #junk.each do |crap|
  #  parameters[crap['name']] = crap['value']
  #end

  #puts parameters
#  puts JSON.pretty_generate(parameters)



end
