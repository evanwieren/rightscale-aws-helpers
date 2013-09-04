require 'RightScaleAPIHelper'

module RS_AWS_Helper
	class connection
		@rs_conn 

		def initialize(options={})
			begin
				@rs_conn = RightScaleAPIHelper::Helper.new(account_id, email, password, format='js', version = 1.0 )
			rescue
				# Need to anotate that connection was not established. Need to raise an exception
			end
		end
	end
end

