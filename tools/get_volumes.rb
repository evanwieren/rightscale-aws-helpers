#!/usr/bin/env ruby

require 'RightScaleAPIHelper'
require 'yaml'
require 'Base64'
require 'json'

@debug = true

def read_config(config_file, environment)
begin
	raw_config = File.read(config_file)
	@APP_CONFIG = YAML.load(raw_config)[environment]
rescue Exception => e
	puts "Failed to read the configuration file"
	puts e.message
	puts e.backtrace.inspect
	exit 1
	end
end


def init(options={})
	# This is the initial connection to RightScale
	begin
		@rs_conn = RightScaleAPIHelper::Helper.new(@APP_CONFIG[:account_id], Base64.decode64(@APP_CONFIG[:username]),
			Base64.decode64(@APP_CONFIG[:password]), format='js' )
	rescue Exception => e
		puts "Failed making the connection to RightScale"
		puts e.message
		puts e.backtrace.inspect
		exit(1)
	end
	# TODO : SHAZBOT : Need to add the connector for AWS. 
	# Working on one side at a time. 
end

def debug(message)
	if @debug == true
		puts message
	end
end


begin 
	# First thing is to read the configuration file.
	read_config(ARGV[0], ARGV[1])
	# now we initiate our connections 
	init
	debug "Init has run"

	resp = @rs_conn.get('/servers')
	puts "Response code: #{resp.code}"
	puts "Response body: "
	puts resp.body

rescue
	# Don't die on me
end