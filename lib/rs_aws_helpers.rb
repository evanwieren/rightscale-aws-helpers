require 'RightScaleAPIHelper'
require 'yaml'

module RS_AWS_Helper

	def read_config(config_file, environment)
		raw_config = File.read(config_file)
		@APP_CONFIG = YAML.load(raw_config)[environment]
	end


	def initialize(options={})
		begin

			@rs_conn = RightScaleAPIHelper::Helper.new(account_id, email, password, format='js', version = 1.0 )
		rescue
			# Need to anotate that connection was not established. Need to raise an exception
		end
	end
end

