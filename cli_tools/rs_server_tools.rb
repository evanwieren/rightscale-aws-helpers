#!/usr/bin/env ruby

require 'RightScaleAPIHelper'
require 'json'


class RSServerTools
  def read_server_inputs(rs_conn, serverID)
    # Do some stuff here
    resp = rs_conn.get("/servers/#{serverID}")

    unless resp.code.to_i == 200
      raise("Invalid response code : #{resp.code}")
    end

    return JSON.parse(resp.body)
  end

  def update_server_inputs(rs_conn, serverID, params = {})
    resp = rs_conn.put("/servers/#{serverID}", params)
    puts "The response code was #{resp.code}."
    puts "The body is null: #{resp.body}"
  end
  
  def update_current_server_inputs(rs_conn, serverID, params = {})
    resp = rs_conn.put("/servers/#{serverID}/current", params)
    puts "The response code was #{resp.code}."
    puts "The body is null: #{resp.body}"
  end
end

begin
  if __FILE__ == $0
    puts "Running the file locally"
  end
end
