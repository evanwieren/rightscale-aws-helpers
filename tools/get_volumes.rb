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
		debug "Read the configuration file"
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
		debug "Connect to RS API complete"
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

def get_servers
	begin

		resp = @rs_conn.get('/servers')

		# 200 Success :: anything else is failure
		unless resp.code == "200"
			#raise "Error requesting server list. Error code #{resp.code}"
			# Not sure that I want to raise an exception. Will give back raw data.
			return {code: resp.code, body: resp.body}
		end

		# Convert the output to json
		server_list = JSON.parse(resp.body)
#		server_list.each do |server|
#			begin
#				puts server
#				puts server["nickname"]
#				ref =  server["href"]	
#				resp =  @rs_conn.get("#{ref}/settings")
#				puts "Response code: #{resp.code}"
#				puts resp.body
#			rescue Exception => e
#				puts e.message
#				puts e.backtrace.inspect
#				exit 1
#			end
#		end
	rescue Exception => e
		raise e
	end
	return {code: resp.code, body: server_list}
end

def get_volumes
	begin
		resp = @rs_conn.get('/ec2_ebs_volumes')
		unless resp.code == '200'
			puts "Failed to gather ec2_ebs_volumes. Error code #{resp.code}"
			return nil
		end

		return JSON.parse(resp.body)
	rescue Exception => e
		puts "Error getting ec2_ebs_volumes"
		puts e.message
		puts e.backtrace.inspect
	end
end

def generic_get (query)
	begin
		resp = @rs_conn.get(query)
		unless resp.code == '200'
			puts "Failed to run query: #{query}.\n Error code #{resp.code}"
			puts "Body: #{resp.body}"
			return nil
		end

		return JSON.parse(resp.body)
	rescue Exception => e
		puts "Error running RightScale request."
		puts e.message
		puts e.backtrace.inspect
	end
end

begin 
	# First thing is to read the configuration file.

	read_config(ARGV[0], ARGV[1])
	# now we initiate our connections 
	init

	#server_list = generic_get '/servers'
	#get_servers
	server_arrays = generic_get('/server_arrays')
	count = 1
	icount = 1 
	server_arrays.each do |array| 
		#puts "#{count} : #{array['nickname']} : #{array["active_instances_count"]}"
		array_intances = generic_get(array["href"] + "/instances")
		array_intances.each do |instance|
			puts "#{icount} : #{instance['nickname']} : #{instance['resource_uid']} : #{instance['cloud_id']}"
			icount += 1
		end

		count += 1
	end

	puts "Total arrays : #{count}"
	puts "Total servers : #{icount}"
	#server_list.each do |server|
	#	puts server 
	#end

	#volume_list = get_volumes
	#volume_list.each do |volume|
	#	puts volume
	#end
	#puts "Listing individual machine"
	#server_info = generic_get "https://my.rightscale.com/api/acct/44210/servers/869991001"
	#puts "server_info is of type #{server_info.class}"
	#server_info.each do |server_item|
	#	puts server_item
	#end

rescue
	# Don't die on me
end