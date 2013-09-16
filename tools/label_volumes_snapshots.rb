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

def get_volumes(aws_connection)
  aws_connection.volumes
end

def get_snapshots(aws_connection)
  aws_connection.snapshots.with_owner("self")
end

def usage()
  puts "Usage: #{__FILE__} <path to config.yml> <environment>"
  exit! 0
end

begin
  unless ARGV.count == 2
    usage()
  end

  #helper = RS_AWS::Helper.new(ARGV[0], ARGV[1])
  @APP_CONFIG = RS_AWS::Helper.read_config(ARGV[0], ARGV[1])
  AWS.config(access_key_id: @APP_CONFIG[:access_key_id], secret_access_key: @APP_CONFIG[:secret_access_key])
  set_aws_connections

  @rs_to_aws_cloud_map.each do |key, ec2|
    instances = ec2.instances
    instances.each do |instance|
      puts instance.id
      instance_attachments = instance.attachments
      instance_attachments.each do |point, attachment| 
        # Returns the volume? ec2.volume.(attachment.volu)
        puts "\t#{attachment.volume.id}"
        instance.tags.each do |instance_tags|
          #value = instance.tags[key]
          puts "#{instance_tags[0]}---#{instance_tags[1]}"

          # if it starts with aws skip. Reserved by amazon.
          unless (instance_tags[0] =~ /^aws/)
            attachment.volume.tag(instance_tags[0], value: instance_tags[1])
            #ec2.tags.create(attachment.volume, key, value)
          end
        end
        #attachment.volume.tags = instance.tags
      end
    end
  end

  #   volumes = get_volumes(ec2)
  #   volumes.each do | volume |
  #     print "#{count} : #{volume.id} "
  #     volume.attachments.each do |attachment|
  #       vol_attach += 1
  #       print attachment.instance.id
  #     end
  #     print "\n"
  #     count += 1
  #   end
  #   snapshots = get_snapshots(ec2)
  #   snapshots.each do |snapshot|
  #     snapshot_count += 1
  #     snapshot.permissions.public? ? perms = "Wide Open" : perms = "Safe"
  #     puts "Snapshot : #{snapshot.id} : #{perms}"
  #   end
  # end

  # count = 1
  # snapshot_count = 0
  # vol_attach = 0

  # @rs_to_aws_cloud_map.each do |key, ec2|
  #   volumes = get_volumes(ec2)
  #   volumes.each do | volume |
  #     print "#{count} : #{volume.id} "
  #     volume.attachments.each do |attachment|
  #       vol_attach += 1
  #       print attachment.instance.id
  #     end
  #     print "\n"
  #     count += 1
  #   end
  #   snapshots = get_snapshots(ec2)
  #   snapshots.each do |snapshot|
  #     snapshot_count += 1
  #     snapshot.permissions.public? ? perms = "Wide Open" : perms = "Safe"
  #     puts "Snapshot : #{snapshot.id} : #{perms}"
  #   end
  # end

  # puts "Snapshots = #{snapshot_count}"
  # puts "Volumes = #{count}"
  # puts "Attached vols = #{vol_attach}"



rescue Exception => e
  puts "Error in executing script."
  puts e.message
  puts e.backtrace.inspect
end


