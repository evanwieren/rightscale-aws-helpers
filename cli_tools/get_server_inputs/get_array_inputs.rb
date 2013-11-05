#!/usr/bin/env ruby

require 'RightScaleAPIHelper'
require 'optparse'
require 'json'
require 'base64'
require 'aws-sdk'
require 'yaml'

# For now this works, but need to rework the module to support a configuration
# method that is similar to what Amazon uses
def process_yaml()

  opts = OptionParser.new

  opts.on("-y", "--yaml PATH_TO_YAML_FILE", String) do |val|
    if File.exist?(val)
      app_config = YAML.load_file(val)
      @username = app_config['username']
      @password = app_config['password']
      @account_id = app_config['account_id']
      if app_config['base64']
        @base64 = true
      end
      #AWS.config(app_config)
    else
      puts "YAML configuration file does not exist. file: %s\nExiting" % val
      exit(1)
    end
  end

  # Assign Variables
  opts.on("-u", "--username RightScaleUsername", String) {|val| @username = val }
  opts.on("-p", "--password RightScalePassword", String) {|val| @password = val }
  opts.on("-a", "--account_id RSAccountID", Integer) {|val| @account_id = val}
  opts.on("-i", "--server_id RSServerID", Integer) {|val| @array_id = val}
  #opts.on("--aws-key Amazon_Key", String) {|val| @aws_key = val }
  #opts.on("--aww-secret Amazon_Secret", String) {|val| @aws_secret = val}
  opts.on("--base64[=OPT]", TrueClass) {|val| @base64 = true}
  opts.on("-h", "--help", "Show Help|Usage Information") do
    puts opts.to_s
    exit(0)
  end

  opts.parse(ARGV)

  begin
    raise OptionParser::MissingArgument if @array_id.nil?
  rescue OptionParser::MissingArgument => e
    puts "Missing mandatory option"
    puts e.message  
    #puts e.backtrace.inspect
    puts opts.to_s
    exit(1)
  end

end

def read_array_inputs(rs_conn, arrayID)
  resp = rs_conn.get("/server_arrays/#{arrayID}")

  unless resp.code.to_i == 200
    raise("Invalid response code : #{resp.code}")
  end

  return JSON.parse(resp.body)
end

def rs_conn()
  if @base64
    api_conn = RightScaleAPIHelper::Helper.new(@account_id, Base64.decode64(@username), Base64.decode64(@password), format="js", version="1.0")
  else
    api_conn = RightScaleAPIHelper::Helper.new(@account_id, @username, @password, format="js", version="1.0")
  end
  return api_conn
end

begin
  if __FILE__ == $0
    begin
      process_yaml
      rs_api = rs_conn

      array_inputs = read_array_inputs(rs_api, @array_id)

      output = {}
      #puts array_inputs.class
      array_inputs.keys.each do |key|
#        # what type of value is the key#
        #puts "#{key}"  = #{array_inputs[key].class}"
        unless array_inputs[key].kind_of? Hash 
          #puts "#{key} is of type #{array_inputs[key].class}"
          output["server_array[#{key}]"]=array_inputs[key]
        else
          # Handle hashes.
          puts "Need to handle this tag separate: #{key} and class is #{array_inputs[key].class}"
          array_inputs[key].keys.each do |item|
            output["server_array[#{key}][#{item}]"] = array_inputs[key][item]
          end
        end
        
      end
      
        #array_inputs['parameters'].keys.each do |key|
      #  puts "Key: #{key}"
      #  puts "Value: #{array_inputs[key]}"
      #end

      json_format = output.to_json
      #puts json_format
      puts JSON.pretty_generate(output)
      

      #puts JSON.pretty_generate(array_inputs)

    rescue
      puts $!.inspect, $@
      # don't blow up on me
    end
  end
end
