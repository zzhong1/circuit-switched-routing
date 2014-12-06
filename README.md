1.Download Core Emulator.(http://www.nrl.navy.mil/itd/ncs/products/core)
2.Create a network in core encironment and run it.
3.Double click any node in the network to open ternimal.
4.Cd to the directory where you store the project file.
5.run gen_weights.rb addrs-to-links.txt output.txt. This will generate weight for each link periodically and write to 	output.txt
6. run routing.rb
7. repeat step 3-7 to wake up every node in the network