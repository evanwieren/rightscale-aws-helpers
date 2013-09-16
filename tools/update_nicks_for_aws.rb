#!/usr/bin/env ruby

require 'RightScaleAPIHelper'
require 'json'
require 'base64'
require 'aws-sdk'
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
  server_list.each do |server|
    debug server
    @rs_to_aws_cloud_map[server[:cloud_id]].instances[server[:aws_id]].tag("Name", value: server[:nick])
  end
end

def update_server_tags(cloud_id, aws_id, tags)
  tags.keys.each do |tag_key|
    @rs_to_aws_cloud_map[cloud_id].instances[aws_id].tag(tag_key, value: tags[tag_key])
  end
end

def usage()
  puts "Usage: #{__FILE__} <path to config.yml> <environment>"
  exit! 0
end

begin
  unless ARGV.count == 2
    usage()
  end

  helper = RS_AWS::Helper.new(ARGV[0], ARGV[1])
  @APP_CONFIG = helper.read_config(ARGV[0], ARGV[1])
  AWS.config(access_key_id: @APP_CONFIG[:access_key_id], secret_access_key: @APP_CONFIG[:secret_access_key])
  set_aws_connections

  rs_helper = RS_AWS::RS_Helper.new(@APP_CONFIG)
  rs_helper.init

  # Array to put all of the servers in.
  aws_server_list = []
  server_list = helper.get_rs_servers


  server_list.each do |server|
    tags = {}
    nick = server['nickname']
    tags["Name"] = nick
    state = server['state']

    if state == "operational"
      # Get the server settings. This is to get the cloud ID and aws_id
      server_settings = helper.get_rs_server_settings(server)

      #server_info = rs_helper.generic_get("https://my.rightscale.com/api/acct/44210/servers/750661001")
      server_info = rs_helper.generic_get(server['href'])

      # get the lineage parameter
      server_info['parameters'].each do |info|
        if info['name'].downcase =~  /lineage$/
          lineage = info['value'].split(':')
          tags['lineage'] = lineage[1]
        end
      end
      # Get the parameters from the system

      #puts server_settings
      aws_server_list.push({tags: tags, aws_id: server_settings['aws_id'], cloud_id: server_settings['cloud_id']})
    end
  end

  array_servers = helper.get_rs_array_servers
  array_servers.each do |server| 
    tags ={
      "Name" => server['nickname'],
    }
    aws_server_list.push({tags: tags, aws_id: server['resource_uid'], cloud_id: server['cloud_id']})
  end

  debug "Updating nicks now."
  aws_server_list.each do |server|
    puts server[:tags]["Name"]
    update_server_tags(server[:cloud_id], server[:aws_id], server[:tags])
  end
  #update_servers(aws_server_list)
  debug "Update complete."

  #aws_server_list.each do |server|
  #  puts server
  #end
rescue Exception => e
  puts "Error in executing script."
  puts e.message
  puts e.backtrace.inspect
end


