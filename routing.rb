require "socket"
require "ipaddr"
require 'time'
require_relative 'graph'

arr = Socket.getifaddrs.reject {|ifaddr|
	!ifaddr.addr.ip? || (ifaddr.flags & Socket::IFF_MULTICAST == 0)
	}.map {|ifaddr| ifaddr.addr}

MULTICAST_ADDR = "224.0.0.1"
PORT = 3000
BIND_ADDR = "0.0.0.0"

send_sockets={}
arr.each do |i|
	if(i.ipv4?)
		sendSocket = UDPSocket.open
		sendSocket.setsockopt(:SOL_SOCKET, :SO_REUSEADDR, 1)
		if(sendSocket.setsockopt(:IPPROTO_IP, :IP_MULTICAST_TTL, 1)<0)
			puts "set socket failed"
		end
		if(sendSocket.bind(i.ip_address,PORT)<0)
			puts "bind failed"
		else
			#puts "socket bind to #{i.ip_address}"
			send_sockets[sendSocket] = i.ip_address

			
		end
	end
end

recvSocket = UDPSocket.new
membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

recvSocket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
recvSocket.setsockopt(:SOL_SOCKET, :SO_REUSEADDR, 1)

recvSocket.bind(BIND_ADDR, PORT)

flood_table={}
time_last_send = Time.new(0)
all_paths_all_ips={}

loop do
	time_now = Time.now
	#send
	if(time_now - time_last_send > 20)
		send_sockets.each do |ss,ip|
			f = File.open("output.txt", "r")
			weight = 0
			other_ip = ""
			f.each_line do |line|
				if line =~ /([0-9]+.[0-9]+.[0-9]+.[0-9]+),([0-9]+.[0-9]+.[0-9]+.[0-9]+),([0-9]+)/
          weight = $3
	 				if ip.eql? $1
	 					other_ip = $2
	 				end
	 				if ip.eql?$2
	 					other_ip = $1
	 				end
	 			end
			end
			f.close
			key = ip + " " + other_ip
			#puts "ip : #{ip}"
			#puts "other ip : #{other_ip}"
			#puts "weight: #{weight}"
			flood_table[key] = weight
			#puts flood_table.inspect
			msg = ""
			msg << ip << "&destination" << "&flooding&"<< flood_table.inspect
			ss.send(msg, 0, MULTICAST_ADDR, PORT)
		end
		time_last_send = time_now
	end
	#recv

	results = IO.select([recvSocket,ARGF],nil,nil,0)
	
	if results
		if results[0].include? recvSocket
	  	msg_recv = recvSocket.recvfrom(2048)
	  	own_ip = false
	  	send_sockets.each do |k,ip|
	  		if (ip.eql? msg_recv[1][2])
	  			own_ip = true
	  		end
	  	end
			if (!own_ip)
				msg_to_array = msg_recv[0].split("&")
		  	source = msg_to_array[0]
		  	destination = msg_to_array[1]
				is_flood = msg_to_array[2].eql? "flooding"
				is_send = msg_to_array[2].eql? "SENDMSG"
				is_ping = msg_to_array[2].eql? "PING"
				is_pingback = msg_to_array[2].eql? "PINGBACK"
				content = msg_to_array[3]
				num_pings = msg_to_array[4].to_i
				delay = msg_to_array[5].to_i
				if (is_flood)
					routing_table = eval(content)
					merge_table = flood_table.merge routing_table
					#puts merge_table.inspect
					#puts flood_table.inspect
					#if (!flood_table.include? source)
					#puts "recieve flood"
					send_sockets.each do |ss,ip|
						if(merge_table != flood_table)
							String msg = ""
							msg << ip << "&destination" << "&flooding&"<< merge_table.inspect
							if(ss.send(msg, 0, MULTICAST_ADDR, PORT)<0)
								puts "sending failed"
							end
							#puts merge_table.inspect
							flood_table =  merge_table
						end
					end
				end
				if is_send
					ss,first_ip = send_sockets.first

					if send_sockets.has_value?(destination)
						puts "recieved " + content + " from " + source
					else
						#puts source
						#puts all_paths_all_ips.inspect
						path = all_paths_all_ips[first_ip][destination]
						out_link_ip = ""
						path.each_with_index do |p,index|
							if !send_sockets.has_value? p
								out_link_ip = path[index-1]
								break
							end
						end
						send_sockets.each do |k,v|
							if v.eql? out_link_ip
								ss = k
							end
						end
						#puts "send "+content+" from "+source+ " to "+destination
						ss.send(msg_recv[0], 0, MULTICAST_ADDR, PORT)		
					end	
				end
				if is_ping
					ss,first_ip = send_sockets.first

					if send_sockets.has_value?(destination)
						puts "PING #{source} " + (num_pings.to_s) + " times"
						temp = destination
							destination = source
							source = temp
							path = all_paths_all_ips[first_ip][destination]
							out_link_ip = ""
							path.each_with_index do |p,index|
								if !send_sockets.has_value? p
									out_link_ip = path[index-1]
									break
								end
							end
							send_sockets.each do |k,v|
								if v.eql? out_link_ip
									ss = k
								end
							end
						#puts "send "+content+" from "+source+ " to "+destination
						msg = ""
						msg << source << "&"<< destination << "&PINGBACK&"<<content<<"&"<<num_pings.to_s<<"&"<<delay.to_s
						num_pings.times do
							time_last_pingback = Time.now
							loop do
								if Time.now - time_last_pingback > delay
									break
								end
							end
							ss.send(msg, 0, MULTICAST_ADDR, PORT)
						end

					else
						#puts source
						#puts all_paths_all_ips.inspect
						path = all_paths_all_ips[first_ip][destination]
						out_link_ip = ""
						path.each_with_index do |p,index|
							if !send_sockets.has_value? p
								out_link_ip = path[index-1]
								break
							end
						end
						send_sockets.each do |k,v|
							if v.eql? out_link_ip
								ss = k
							end
						end
						#puts "send "+content+" from "+source+ " to "+destination
						ss.send(msg_recv[0], 0, MULTICAST_ADDR, PORT)		
					end	
				end
				if is_pingback
					ss,first_ip = send_sockets.first

					if send_sockets.has_value?(destination)
						puts "PING FROM " + source
					else
						#puts source
						#puts all_paths_all_ips.inspect
						path = all_paths_all_ips[first_ip][destination]
						out_link_ip = ""
						path.each_with_index do |p,index|
							if !send_sockets.has_value? p
								out_link_ip = path[index-1]
								break
							end
						end
						send_sockets.each do |k,v|
							if v.eql? out_link_ip
								ss = k
							end
						end
						#puts "send "+content+" from "+source+ " to "+destination
						ss.send(msg_recv[0], 0, MULTICAST_ADDR, PORT)		
					end	
				end
			end
			#puts "flood_table start:"
			#puts flood_table.inspect
			#puts "flood_table end"
			
			#puts "-------------------------------------------------------------"
			
			send_sockets.each do |ss, ip|
				graph = Graph.new(ip,flood_table);
				graph.ReadConfig
				graph.Dijkstra
				all_paths= graph.shortest_paths
				all_paths_all_ips[ip] = all_paths
			#	puts "shortest paths from #{ip} to all other ip"
			#	all_paths.each do |k,v|
			#		print "to #{k}: "
			#		puts v.inspect
			#	end
			#	puts "#{ip} shortest paths finished"
			end
			#puts "--------------------------------------------------------------"
		elsif results[0].include? ARGF

			a = ARGF.gets 
			if a =~ /SENDMSG\s+([0-9]+.[0-9]+.[0-9]+.[0-9]+)\s+(\w+)/
				destination = $1
				content = $2
				ss,source = send_sockets.first
				msg = ""
				msg << source << "&"<< destination << "&SENDMSG&"<< content
				if send_sockets.has_value?(destination)
					puts "recieved " + content + " from " + source
				else
					#puts all_paths_all_ips.inspect
					path = all_paths_all_ips[source][destination]
					if path
						out_link_ip = ""
						path.each_with_index do |p,index|
							if !send_sockets.has_value? p
								out_link_ip = path[index-1]
								break
							end
						end
						send_sockets.each do |k,v|
							if v.eql? out_link_ip
								ss = k
							end
						end
						puts "send "+content+" from "+source+ " to "+destination
						ss.send(msg, 0, MULTICAST_ADDR, PORT)		
					else
						puts "SENDMSG ERROR: HOST UNREACHABLE"
					end	
				end
			#PING [DST] [NUMPINGS] [DELAY]
			elsif a =~ /PING\s+([0-9]+.[0-9]+.[0-9]+.[0-9]+)\s+(\d+)\s+(\d+)/
				destination = $1
				num_pings = $2.to_i
				delay = $3.to_i
				ss,source = send_sockets.first
				
				content="empty"
				msg = ""
				msg << source << "&"<< destination << "&PING&"<<content<<"&"<<num_pings.to_s<<"&"<<delay.to_s
				if send_sockets.has_value?(destination)
					while(num_pings>0) do
						time_last_ping = Time.now
						loop do
							if Time.now - time_last_ping > delay
								break
							end
						end
						puts "ping from #{destination}"
						num_pings=num_pings-1
					end
				else
					#puts all_paths_all_ips.inspect
					path = all_paths_all_ips[source][destination]
					if path==nil
						puts "PING ERROR: #{destination} UNREACHABLE"
					else
						out_link_ip = ""
						path.each_with_index do |p,index|
							if !send_sockets.has_value? p
								out_link_ip = path[index-1]
								break
							end
						end
						send_sockets.each do |k,v|
							if v.eql? out_link_ip
								ss = k
							end
						end
						#puts "send ping "+" from "+source+ " to "+destination
						ss.send(msg, 0, MULTICAST_ADDR, PORT)
					end		
				end	

			#TRACEROUTE [DST]
			elsif a =~ /TRACEROUTE\s+([0-9]+.[0-9]+.[0-9]+.[0-9]+)/
				node.TraceRoute($1, $2, $3)
			#recieve from socket
			end
		end
	end
end

=begin
recvSocket = UDPSocket.new
membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

recvSocket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
recvSocket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

recvSocket.bind(BIND_ADDR, PORT)

loop do
  message, _ = recvSocket.recvfrom(255)
  puts message
end
=end




