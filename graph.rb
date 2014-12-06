class Graph

  def initialize(source,hash)
    @hash = hash
    @source = source
    @graph = {}
    @previous = {}
    @distance = {}
    @nodeQueue = []
    @FIXNUM_MAX = (2**(0.size * 8 -2) -1)  #use as infiite 
    @all_ip = {}
  end

  def source
    @source 
  end

  def graph
    @graph
  end

  def previous
    @previous
  end

  def distance 
    @distance
  end

  def nodeQueue
    @nodeQueue
  end

  def FIXNUM_MAX
    @FIXNUM_MAX
  end

  def nodeAddr 
    @nodeAddr
  end

  def ReadConfig
    @hash.each do |k,v|
      if key_array = k.split(" ")
        ip_1 = key_array[0]
        ip_2 = key_array[1]
        if(!ip_2.eql? "")
         # puts k
          weight = v
          @all_ip[ip_1] = true
          @all_ip[ip_2] = true
          @graph[ip_1] = Hash.new if @graph[ip_1] == nil
          @graph[ip_1][ip_2] = weight.to_i
          @graph[ip_2] = Hash.new if @graph[ip_2] == nil
          @graph[ip_2][ip_1] = weight.to_i
        end
      end
    end

    #Talk to Andrew about that 
    nodeAddr = {}
    File.open("nodes-to-addrs.txt", "r") do |f|
      f.each_line do |line|
        if line =~ /(n[0-9]+)\s+([0-9]+.[0-9]+.[0-9]+.[0-9]+)/
          nodeAddr[$1] = [] if nodeAddr[$1] == nil
          nodeAddr[$1].push($2)
        end
      end
    end
    nodeAddr.each{|n, arr|
      arr.each{|addr1|
        arr.each{|addr2|
          @graph[addr1] = Hash.new if @graph[addr1] == nil
          @graph[addr1][addr2] = 0
        }
      }
    }
  end

  def ExtractMin
    min = @FIXNUM_MAX
    tmp = @nodeQueue.first
    @nodeQueue.each{|node|
      if min > @distance[node]
        min = @distance[node]
        #puts "node: #{node}, distance: #{@distance[node]}"
        tmp = node
      end
    }
    @nodeQueue.delete(tmp)
    tmp
  end

  def Dijkstra
    @distance[@source] = 0
    @graph.keys.each { |node|
      unless node == @source
        @distance[node] = @FIXNUM_MAX
        @previous[node] = nil
      end
    }
    @nodeQueue = @graph.keys.dup

    #puts "NodeQueue: #{@nodeQueue}"

    while @nodeQueue.empty? != true do
      node = self.ExtractMin

      #puts "node: #{node}, distance: #{distance[node]}, keys: #{@graph[node].keys}"

      @graph[node].keys.each{ |vertex|
        if @nodeQueue.include?(vertex)
          #puts "vertex: #{vertex}"
          alt = @distance[node] + @graph[node][vertex]
          #puts @distance[node]
          if alt < distance[vertex]
            @distance[vertex] = alt
            @previous[vertex] = node
            #puts "find new path: #{vertex}, #{@distance[vertex]}"
          end
        end
      }
    end
  end

  def ShortestPath(dest)
    path = []
    tmp = dest
    while previous[tmp] do
      path.unshift(tmp)
      tmp = previous[tmp]
    end
    path
  end

  def shortest_paths
    all_paths = {}
    @all_ip.each do |k,v|
      all_paths[k] = ShortestPath(k)
    end
    all_paths
  end

end

=begin
graph = Graph.new("10.0.0.21")
#puts graph.source
graph.ReadConfig
graph.Dijkstra
a = graph.ShortestPath("10.0.16.21")
puts a
=end
