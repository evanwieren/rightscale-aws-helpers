#!/usr/bin/env ruby

#require 'RightScaleAPIHelper'
require 'json'
require 'base64'
require 'aws-sdk'
require 'yaml'
require_relative '../lib/rs_aws_helpers.rb'

@debug = true

# Map of RightScale Regions to Amazon Regions. 
# Need this or items will not work.

@aws_cloud_map = {
    'us-east-1' => 1,
    'us-west-1' => 3,
    'us-west-2' => 6,
    'ap-southeast-1' => 4,
    'ap-southeast-2' => 8,
    'ap-northeast-1' => 5,
    'sa-east-1' => 7,
    'eu-west-1' => 2
}

def set_aws_connections()

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

# Pre: given aws server id and aws region
# Post: return the array of block devices.
def get_instance_volumes(aws_id, aws_region)
  @ec2 = @rs_to_aws_cloud_map[@aws_cloud_map[aws_region]]
  server = @ec2.instances[aws_id]
  unless server.exists?
    puts "Server #{aws_id} does not exist.\nExiting..."
    exit (1)
  end

  server.block_devices
end

# Pre: give an array of block devices
# Post: for ebs volumes return an array of snapshots.
def get_snapshots_from_block_array(block_devices)
  volume_list = []
  block_devices.each do |device|
    unless device[:ebs].nil?
      volume =  @ec2.volumes[device[:ebs][:volume_id]]
      debug("Volume of id: #{volume.id}")
      volume_list.push(volume)
    end
  end
  return volume_list
end

# Pre given a server and region
# provide a string with the next available device id /dev/sdx
def get_next_device_name(aws_id, aws_region)

end

# Pre: given aws server id and region
# Post: return the snapshots for the attached ebs volumes
def get_snapshots_from_server(aws_id, aws_region)
  device_list = get_instance_volumes(aws_id, aws_region)

  #get_snapshots_from_block_array(device_list)
  all_snapshots = @rs_to_aws_cloud_map[@aws_cloud_map[aws_region]].snapshots.with_owner("self")

  # will hold the snap
  current_snaps = {}

  # need to create an array of the newest snapshots
  all_snapshots.each do |snap|
    #debug("From volume: #{snap.volume_id} and snap: #{snap.id} time: #{snap.start_time}")
    device_list.each do |volume|
      if volume[:ebs][:volume_id] == snap.volume_id
        if defined?(curent_snaps[snap.volume_id][1]).nil?
          current_snaps[snap.volume_id] = [snap.id, snap.start_time, snap]
        elsif Time.parse(current_snaps[snap.volume_id][1]) < Time.parse(snap.start_time)
          current_snaps[snap.volume_id] = [snap.id, snap.start_time, snap]
        end
      end
    end
  end

  snaplist = []
  current_snaps.each_key do |volume|
    debug "Found snap #{current_snaps[volume][0]} with timestamp: #{current_snaps[volume][1]}"
    snaplist.push(current_snaps[volume][2])
  end

  return snaplist

end

def create_volumes_from_snap(snapshots, aws_region, availability_zone)
  ec2 = @rs_to_aws_cloud_map[@aws_cloud_map[aws_region]]
  volumes = []
  snapshots.each do |snap|
    volume = snap.create_volume(availability_zone)
    debug("Created volume with ID: #{volume.id}")
    volumes.push(volume)
  end

  return volumes
end

def get_server_availability_zone(aws_id, aws_region)
  ec2 = @rs_to_aws_cloud_map[@aws_cloud_map[aws_region]]
  ec2.instances[aws_id].availability_zone
end

def debug(message)
  if @debug == true
    puts message
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


  printf ('Enter the master aws server id: ')
  master_aws_id = STDIN.readline
  master_aws_id.rstrip!

  printf ('Enter the region of the master server: ')
  master_aws_region = STDIN.readline
  master_aws_region.rstrip!

  printf ('Enter the slave aws server id: ')
  slave_aws_id = STDIN.readline
  slave_aws_id.rstrip!

  printf ('Enter the region of the slave server: ')
  slave_aws_region = STDIN.readline
  slave_aws_region.rstrip!

  @APP_CONFIG = RS_AWS::Helper.read_config(ARGV[0], ARGV[1])
  AWS.config(access_key_id: @APP_CONFIG[:access_key_id], secret_access_key: @APP_CONFIG[:secret_access_key])
  set_aws_connections

  snapshots = get_snapshots_from_server(master_aws_id, master_aws_region)
  #master_aws_az = get_server_availability_zone(master_aws_id, master_aws_region)
  #debug("AZ is #{master_aws_az}")

  # now -- we need to copy the snapshot if not same region
  # then create volumes from them and attach to server
  # to start with, I am going to skip the copy and create volumes and attach to a node

  new_volumes = create_volumes_from_snap(snapshots, master_aws_region, get_server_availability_zone(master_aws_id, master_aws_region))

  # So I can create volumes from snaps. Now to add them to a machine.
  # Steps to attach a machine
  # 1. Get list of attached devices
  # 2. Come up with next slot device name
  # 3. attach disk




rescue Exception => e
  puts "Error in executing script."
  puts e.message
  puts e.backtrace.inspect
end


