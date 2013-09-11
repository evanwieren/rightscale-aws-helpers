require 'RightScaleAPIHelper'
require 'yaml'
require 'aws-sdk'

module RS_AWS

	class Helper

		# Read the configuration file for both  AWS and RS
		def read_config(config_file, environment)
		  begin
		    raw_config = File.read(config_file)
		    @APP_CONFIG = YAML.load(raw_config)[environment]
		    debug "Read the configuration file"
		    return @APP_CONFIG
		  rescue Exception => e
		  	raise "Failed to read the configuration file"
	    end
		end

		def initialize(config_file, environment)
			begin
				read_config(config_file, environment)
				@rs = RS_Helper.new(@APP_CONFIG)
				@rs.init
			rescue
				raise
			end
		end

		def update_config(config_file, environment)
			read_config(config_file, environment)
			@rs.set_config(@APP_CONFIG)
		end

		def get_rs_servers
			@rs.get_servers
		end

		def get_rs_array_servers
			@rs.get_array_servers
		end

		def get_rs_to_aws_server_mapping (server)
			@rs.get_aws_server_id(server)
		end

		def get_rs_server_settings(server)
			@rs.get_current_server_settings(server)
		end
 	end


	# Class the will handle the RightScale side of things.
	# This will probably need to go into another file later
	class RS_Helper

		def get_aws_server_id(server)
			settings = get_current_server_settings(server)
			return settings['aws_id']
		end

		def get_current_server_settings(server)
			begin
				generic_get(server['href'] + "/current/settings")
			rescue
				raise
			end
		end


		def set_config(config)
			@APP_CONFIG = config
		end

		def initialize(config)
			@APP_CONFIG = config
		end

		def init(options={})
		  # This is the initial connection to RightScale
		  begin
		    @rs_conn = RightScaleAPIHelper::Helper.new(@APP_CONFIG[:account_id], Base64.decode64(@APP_CONFIG[:username]),
		      Base64.decode64(@APP_CONFIG[:password]), format='js' )
		  rescue Exception => e
		    raise "Failed making the connection to RightScale"
		  end
		end

		def get_array_servers
			resp = @rs_conn.get('/server_arrays')

			unless resp.code == "200"
				raise "Error requesting array list. Error code : #{resp.code}\nHtml Body : #{resp.body}"
			end

			server_list = []
			JSON.parse(resp.body).each do |array| 
				array_intances = generic_get(array["href"] + "/instances")
				array_intances.each do |instance|
					server_list.push(instance)
					#puts "#{icount} : #{instance['nickname']} : #{instance['resource_uid']} : #{instance['cloud_id']}"
				end
			end
			return server_list
		end

		# Get a list of servers and return them as a json array.
		def get_servers
			begin
				resp = @rs_conn.get('/servers')

				# 200 Success :: anything else is failure
				unless resp.code == "200"
					raise "Error requesting server list. Error code #{resp.code}"
				end
				# Convert the output to json
				server_list = JSON.parse(resp.body)
				return server_list
			rescue Exception => e
				raise e
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

	end
end


	

