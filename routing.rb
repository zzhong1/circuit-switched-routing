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
		sendSocket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)
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
recvSocket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

recvSocket.bind(BIND_ADDR, PORT)

flood_table={}
time_last_send = Time.new(0)

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
			String msg = ""
			msg << ip << "&destination" << "&flooding&"<< flood_table.inspect
			ss.send(msg, 0, MULTICAST_ADDR, PORT)
		end
		time_last_send = time_now
	end
	#recv
	a = IO.select([recvSocket,ARGF],nil,nil,0)
	
	if a
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
			is_flood = msg_to_array[2].eql? "flooding"
			routing_table = eval(msg_to_array[3])
			if (is_flood)
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
						puts merge_table.inspect
						flood_table =  merge_table
					end
				end
			end
		end
		#puts "flood_table start:"
		#puts flood_table.inspect
		#puts "flood_table end"
		
		puts "-------------------------------------------------------------"
		send_sockets.each do |ss, ip|
			graph = Graph.new(ip,flood_table);
			graph.ReadConfig
			graph.Dijkstra
			a = graph.shortest_paths
			puts "shortest paths from #{ip} to all other ip"
			a.each do |k,v|
				print "to #{k}: "
				puts v.inspect
			end
			puts "#{ip} shortest paths finished"
		end
		puts "--------------------------------------------------------------"
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




