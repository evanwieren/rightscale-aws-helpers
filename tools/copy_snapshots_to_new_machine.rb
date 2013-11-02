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
def get_instance_block_devices(aws_id, aws_region)
  @ec2 = get_aws_conn(aws_region)
  server = @ec2.instances[aws_id]
  unless server.exists?
    puts "Server #{aws_id} does not exist.\nExiting..."
    exit (1)
  end

  server.block_devices
end

# Pre: give an array of block devices
# Post: for ebs volumes return an array of snapshots.
def get_volumes_from_block_array(block_devices)
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

# Pre: given aws server id and region
# Post: return the snapshots for the attached ebs volumes
def get_snapshots_from_server(aws_id, aws_region)
  device_list = get_instance_block_devices(aws_id, aws_region)

  #get_snapshots_from_block_array(device_list)
  all_snapshots = get_aws_conn(aws_region).snapshots.with_owner("self")

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

  snapshots = []
  current_snaps.each_key do |volume|
    debug "Found snap #{current_snaps[volume][0]} with timestamp: #{current_snaps[volume][1]}"
    snapshots.push(current_snaps[volume][2])
  end

  return snapshots

end

def create_volumes_from_snap(snapshots, aws_region, availability_zone)
  volumes = []
  snapshots.each do |snap|
    volume = snap.create_volume(availability_zone)
    debug("Created volume with ID: #{volume.id}")
    volumes.push(volume)
  end

  return volumes
end

def get_server_availability_zone(aws_id, aws_region)
  ec2 = get_aws_conn(aws_region)
  ec2.instances[aws_id].availability_zone
end

def get_free_device_mapping(aws_id, aws_region)
  block_devices = get_instance_block_devices(aws_id, aws_region)
  alphabet = ("d".."z").to_a

  debug ("Begin get_free_device_mapping function")

  # This array will hold the letters that are available for sd[a..z] devices.
  device_available = {}

  # Populate the hash for the alphabet
  alphabet.each do |letter|
    device_available[letter] = true
  end

  block_devices.each do |device|
    if ( device[:device_name] =~ /^\/dev\/sd/ )
      debug (" Removing device from list #{device[:device_name][7]}" )
      device_available[device[:device_name][7]] = false
    end
  end

  valid_device = ""
  alphabet.each do |letter|
    if ( device_available[letter] )
      valid_device = "/dev/sd" + letter
      break
    end
  end

  debug "The device is #{valid_device}"
  return valid_device

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

def label_volumes(volumes, tag_name, tag_value)
  volumes.each do |volume|
    volume.tag(tag_name, value: tag_value)
  end
end

def attach_volumes_to_instance(aws_id, aws_region, volumes, device)
  debug ("Begin function: attach_volumes_to_instance")
  device_number = 1
  @ec2 = get_aws_conn(aws_region)
  instance = @ec2.instances[aws_id]
  volumes.each do |volume|
    debug("Attaching #{volume.id} as #{device}#{device_number.to_s}")
    volume.attach_to(instance, device + device_number.to_s)
    device_number +=1
  end
end

# Just so I do not have to repeat this over and over like I already have.
def get_aws_conn(aws_region)
  ec2conn = @rs_to_aws_cloud_map[@aws_cloud_map[aws_region]]
  if ec2conn.nil? or ec2conn == ""
    raise("'#{aws_region}' is not a valid aws region.")
  end
  return ec2conn
end

# Should return list of snapshot info
# Given array of snapshots, from_region, and to_region
# Post = this will return the snapshot objects.
def copy_snapshots_between_regions(snapshots, from_region, to_region)
  if from_region == to_region
    raise('Unable to copy snapshot to same region')
  end

  debug('Begin copy_snapshots_between_regions function')
  ec2 = get_aws_conn(to_region)
  new_snapshots = []
  snapshots.each do |snapshot|
    new_snapshot_id =  ec2.client.copy_snapshot({source_region:  from_region, source_snapshot_id: snapshot.id})[:snapshot_id]
    debug("New snaphot_id is #{new_snapshot_id}")
    new_snapshots.push(ec2.snapshots[new_snapshot_id])
  end
  debug('End copy_snapshots_between_regions function')
  return new_snapshots
end

begin

  
  #unless (ARGV.count == 2)
  #  usage()
  #end

  @APP_CONFIG = RS_AWS::Helper.read_config(ARGV[0], ARGV[1])
  AWS.config(access_key_id: @APP_CONFIG[:access_key_id], secret_access_key: @APP_CONFIG[:secret_access_key])
  set_aws_connections



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


  snapshots = get_snapshots_from_server(master_aws_id, master_aws_region)
  new_snapshots = copy_snapshots_between_regions(snapshots, master_aws_region, slave_aws_region)

  #snapshots_completed = false
  #
  #:pending
  #:completed
  #:error
  temp_snapshot_list = new_snapshots.clone
  until temp_snapshot_list.empty? do
    temp_snapshot_list.reject! {|snapshot| snapshot.status == :completed}
    debug "There are #{temp_snapshot_list.length} snapshots still copying."
    temp_snapshot_list.each do |snapshot|
      if snapshot.status == :error
        raise "At least on snapshot is in error state. Snapshot #{snapshot.id} has a status of #{snapshot.status}"
      end
    end
    sleep(30)

  end


  new_snap_ids.each do |snap_id|
    puts "New snapshot id is : #{snap_id}"
  end
  ##master_aws_az = get_server_availability_zone(master_aws_id, master_aws_region)
  ##debug("AZ is #{master_aws_az}")
  #
  ## now -- we need to copy the snapshot if not same region
  ## then create volumes from them and attach to server
  ## to start with, I am going to skip the copy and create volumes and attach to a node
  #
  #
  ## need to change some of this. The functionality is going to change due to the copy between region function. It only
  ## returns the id of the snap, and not the snapshot. Therefore, need to get the ids, and then pass that along, or make
  ## a function that will create new volumes based upon a list of ids and not of snapshots.
  #new_volumes = create_volumes_from_snap(snapshots, master_aws_region, get_server_availability_zone(master_aws_id, master_aws_region))
  #
  ## 1. Get list of attached devices
  ## 2. Come up with next slot device name
  ## 3. attach disk
  #
  #label_volumes(new_volumes, "Name", "ERIC WAS HERE")
  #
  #
  #attach_volumes_to_instance(slave_aws_id, slave_aws_region, new_volumes, get_free_device_mapping(slave_aws_id,slave_aws_region))



rescue Exception => e
  puts "Error in executing script."
  puts e.message
  puts e.backtrace.inspect
end


