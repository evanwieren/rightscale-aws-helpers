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
  opts.on("-i", "--server_id RSServerID", Integer) {|val| @server_id = val}
  #opts.on("--aws-key Amazon_Key", String) {|val| @aws_key = val }
  #opts.on("--aww-secret Amazon_Secret", String) {|val| @aws_secret = val}
  opts.on("--base64[=OPT]", TrueClass) {|val| @base64 = true}
  opts.on("-h", "--help", "Show Help|Usage Information") do
    puts opts.to_s
    exit(0)
  end

  opts.parse(ARGV)

end


def rs_conn()
  if @base64
    api_conn = RightScaleAPIHelper::Helper.new(@account_id, Base64.decode64(@username), Base64.decode64(@password), format="js", version="1.0", verify_ssl = false)
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

      resp = rs_api.get("/deployments/")
      puts "Return code = #{resp.code}"
      
      deployments =  JSON.parse(resp.body)

      deployment_list = []
      deployments.each do |deployment|
          deployment_list.push ("#{deployment['nickname']} : #{deployment['href']}")
      end
      deployment_list = deployment_list.sort
      puts deployment_list
      


#      output = {}
#      #puts server_inputs.class
#      server_inputs.keys.each do |key|
##        # what type of value is the key
##        puts "#{key} = #{server_inputs[key].class}"
#        if server_inputs[key].kind_of? String
#          output["server[#{key}]"]=server_inputs[key]
#        else
#          puts server_inputs[key]
#        end
#        
#      end
#      server_inputs['parameters'].each do |line|
#        #puts "#{line['name']} = #{line['value']}"
#        output["server[parameters][#{line['name']}]"] = line['value']
#      end
#      #server_inputs['parameters'].keys.each do |key|
#      #  puts "Key: #{key}"
#      #  puts "Value: #{server_inputs[key]}"
#      #end
#
#      #json_format = server_inputs.to_json
#      json_format = output.to_json
#      #puts json_format
#      puts JSON.pretty_generate(output)
#      


      # do something
    rescue
      puts $!.inspect, $@
      # don't blow up on me
    end
  end
end
