require_relative 'test'
require "socket"

MULTICAST_ADDR = "224.0.0.1"
PORT = 3000

socket = UDPSocket.open
socket.setsockopt(:IPPROTO_IP, :IP_MULTICAST_TTL, 1)
buff = Time.now
socket.send(Test.new.inspect, 0, MULTICAST_ADDR, PORT)
socket.close