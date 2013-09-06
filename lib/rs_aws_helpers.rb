require 'RightScaleAPIHelper'
require 'yaml'

module RS_AWS_Helper

	class RS_AWS_Helper

		# Read the configuration file for both  AWS and RS
		def read_config(config_file, environment)
		  begin
		    raw_config = File.read(config_file)
		    @APP_CONFIG = YAML.load(raw_config)[environment]
		    debug "Read the configuration file"
		  rescue Exception => e
		    puts "Failed to read the configuration file"
		    puts e.message
		    puts e.backtrace.inspect
		    exit 1
	    end
		end
 	end

	end

	class AWS_Helper
		# TODO : SHAZBOT : Put some stuff here. 
		# Not the right file for this stuff.
	end

	# Class the will handle the RightScale side of things.
	# This will probably need to go into another file later
	class RS_Helper

		# TODO : SHAZBOT : Need to move some code into here so that 
		# I am not copying the same code over and over. That is bad.

	end
end


	

