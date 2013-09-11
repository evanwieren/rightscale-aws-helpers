#!/usr/bin/env ruby

require 'RightScaleAPIHelper'
require 'json'
require 'base64'
require 'AWS'
require 'yaml'
require_relative '../lib/rs_aws_helpers.rb'

# Map of RightScale Regions to Amazon Regions. 
# Need this or items will not work.
def set_aws_connections

  @rs_to_aws_cloud_map = {
    1 => AWS::EC2.new(region: 'us-east-1'),
    3 => AWS::EC2.new(region: 'us-west-1'),
    6 => AWS::EC2.new(region: 'us-west-2'),
    4 => AWS::EC2.new(region: 'ap-southeast-1'),
    8 => AWS::EC2.new(region: 'ap-southeast-2'),
    5 => AWS::EC2.new(region: 'ap-northeast-1'),
    7 => AWS::EC2.new(region: 'sa-east-1'),
    2 => AWS::EC2.new(region: 'eu-west-1')
  }
end

def debug(message)
  if @debug == true
    puts message
  end
end

def update_servers(server_list)
  puts "Updating Servers"
  server_list.each do |server|
    puts server
    @rs_to_aws_cloud_map[server[:cloud_id]].instances[server[:aws_id]].tag("Name", value: server[:nick])

      # Write the tag on the server
      #which_ec2_conn(server_settings['cloud_id']).instances[aws_id].tag("Name", :value => server['nickname'])
  end
end

def usage()
  puts "Usage: #{__FILE__} <path to config.yml> <environment>"
  exit 0
end

begin
  unless ARGV.count == 2
    usage()
  end

  helper = RS_AWS::Helper.new("../../config.yml", "development")
  @APP_CONFIG = helper.read_config("../../config.yml", "development")
  AWS.config(access_key_id: @APP_CONFIG[:access_key_id], secret_access_key: @APP_CONFIG[:secret_access_key],
    region: 'us-west-2')
  set_aws_connections

  # Array to put all of the servers in.
  aws_server_list = []

  # Get the server list.
  server_list = helper.get_rs_servers

  server_list.each do |server|
    nick = server['nickname']
    state = server['state']
    if state == "operational"
      server_settings = helper.get_rs_server_settings(server)
      aws_server_list.push({nick: nick, aws_id: server_settings['aws_id'], cloud_id: server_settings['cloud_id']})
    end
  end

  array_servers = helper.get_rs_array_servers
  array_servers.each do |server| 
    aws_server_list.push({nick: server['nickname'], aws_id: server['resource_uid'], cloud_id: server['cloud_id']})
  end

  debug "Updating nicks now."
  update_servers(aws_server_list)
  debug "Update complete."

  #aws_server_list.each do |server|
  #  puts server
  #end
rescue
  puts "Error in executing script."
  puts e.message
  puts e.backtrace.inspect
end


