require 'RightScaleAPIHelper'
require 'yaml'

module RS_AWS

	class Helper

		# Read the configuration file for both  AWS and RS
		def read_config(config_file, environment)
		  begin
		    raw_config = File.read(config_file)
		    @APP_CONFIG = YAML.load(raw_config)[environment]
		    debug "Read the configuration file"
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



 	end


	class AWS_Helper
		# TODO : SHAZBOT : Put some stuff here. 
		# Not the right file for this stuff.
	end

	# Class the will handle the RightScale side of things.
	# This will probably need to go into another file later
	class RS_Helper

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

		# Get a list of servers and return them as a json array.
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
				return {code: resp.code, body: server_list}
			rescue Exception => e
				raise e
			end
		end
	end
end


	

