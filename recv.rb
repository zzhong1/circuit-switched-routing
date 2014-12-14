require "socket"
require "ipaddr"
require_relative 'test'
MULTICAST_ADDR = "224.0.0.1"
BIND_ADDR = "0.0.0.0"
PORT = 3000

socket = UDPSocket.new
membership = IPAddr.new(MULTICAST_ADDR).hton + IPAddr.new(BIND_ADDR).hton

socket.setsockopt(:IPPROTO_IP, :IP_ADD_MEMBERSHIP, membership)
socket.setsockopt(:SOL_SOCKET, :SO_REUSEPORT, 1)

socket.bind(BIND_ADDR, PORT)

loop do
  message, _ = socket.recvfrom(2048)
  puts "buffer recieved: " + message
 	puts "after call eval: " + (eval message).class.inspect

end