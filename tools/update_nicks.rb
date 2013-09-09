#!/usr/bin/env ruby

require 'RightScaleAPIHelper'
require 'json'
require 'base64'
#require 'AWS'
require 'yaml'
require_relative '../lib/rs_aws_helpers.rb'

# Map of RightScale Regions to Amazon Regions. 
# Need this or items will not work.
@rs_to_aws_cloud_map = {
  1 => 'us-east-1',
  3 => 'us-west-1',
  6 => 'us-west-2',
  4 => 'ap-southeast-1',
  8 => 'ap-southeast-2',
  5 => 'ap-northeast-1',
  7 => 'sa-east-1',
  2 => 'eu-west-1'
}

def debug(message)
  if @debug == true
    puts message
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

def which_ec2_conn(rs_cloud_id)
      case rs_cloud_id
      when 1
        ec2conn = @ec2
      when 3
        ec2conn = @ec2.regions['us-west-1']
      else
        ec2conn = @ec2
      end
      return ec2conn
end

def update_servers(server_list)
  puts "Updating Servers"
  server_list.each do |server|
    # Don't do anything if the server is not in operational state'
    if server['state'] == "operational"
      resp = @api_conn.get(server['href'].sub(/^.*servers/, "/servers") + "/current/settings")
      server_settings = JSON.parse(resp.body)
      aws_id = server_settings['aws_id']

      # Write the tag on the server
      which_ec2_conn(server_settings['cloud_id']).instances[aws_id].tag("Name", :value => server['nickname'])
    end
  end
end

begin

  helper = RS_AWS::Helper.new("../../config.yml", "development")
  result = helper.get_rs_servers

  unless result[:code] == '200'
    puts "Failed to get list."
    puts result[:body]
    exit 1
  end

  count = 0
  operational = 0
  stopped = 0
  result[:body].each do |server|
    nick = server['nickname']
    state = server['state']
    if state == "operational"
      operational += 1
    elsif state == "stopped"
      stopped += 1
    end
    puts "#{count}: #{nick} : #{state}"
    count += 1
  end

  puts "Stopped = #{stopped}"
  puts "Operational = #{operational}"


#  @ec2 = AWS::EC2.new # Connects to us-east-1

#  resp = @api_conn.get("/servers")
#  server_list = JSON.parse(resp.body)

#  update_servers(server_list)


  # This is broken until I add a bunch of try and catches as the rightscale api
  # is a bit broken when it comes to server arrays.

  # resp = @api_conn.get("/server_arrays")
# server_arrays = JSON.parse(resp.body)
# puts "Updating Array Servers"
# puts server_arrays
#
# server_arrays.each do |server_array|
# puts server_array
# if server_array['active_instances_count'].to_i > 0
# resp = @api_conn.get(server_array['href'].sub(/^.*server_arrays/, "/server_arrays") + "/instances")
# array_instances = JSON.parse(resp.body)
# array_instances.each do |instance|
# #puts instance
# puts "#{instance['nickname']} = #{instance['resource_uid']}"
# ec2conn = which_ec2_conn(instance['cloud_id'])
# puts "cloud_id = #{instance['cloud_id']}"
# unless ec2conn.nil?
# ec2conn.instances[instance['resource_uid']].tag("Name", :value => instance['nickname'])
# end
#
## aws.create_tag(instance['resource_uid'], [{'Name' => instance['nickname']}])
# end
# end
# end
end


