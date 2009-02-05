require 'net/ssh'
require 'rubygems'
require 'time'
require 'singleton'
include Net

class Blamewidth
  include Singleton
  attr_reader :traffic_and_speed
      
  def traffic_and_speed
    traffic_in = get_speed(:download)
    traffic_out = get_speed(:upload)
    @traffic_and_speed = traffic_in.merge(traffic_out) { |k,x,y| x+y}
  end
  
  def get_speed(type= :download)
    enum_type = {:download => true, :upload => false}
    
    traffic_first = retrieve_iptables_stats(enum_type[type])
    sleep(1)
    traffic_last = retrieve_iptables_stats(enum_type[type])
    
    seconds_elapsed = traffic_last[0] - traffic_first[0]
    traffic_first[1].merge(traffic_last[1]) {|k,x,y| [y, ((y-x)/1024)/seconds_elapsed]}
  end
  
  def sort_traffic_and_speed(column)
    index = {:download => 0, :downloadspeed =>1, :upload =>2, :uploadspeed =>3}
    traffic_and_speed.sort { |a, b| a[1][ index[column] ] <=> b[1][ index[column] ] }
  end
  
  def blame(order_by=:download)
    puts "IP ADDRESS\tIN(KB)\tDL(KB/s)\tOUT(KB)\tUL(KB/s)"
    sort_traffic_and_speed(order_by).reverse.each do |ip, in_and_out|
      traffic_in, download, traffic_out, upload = in_and_out
      puts "#{ip}\t#{traffic_in/1024}\t#{download}\t#{traffic_out/1024}\t#{upload}"
    end
  end
  
  def session
    return @session if @session
    @session = Net::SSH.start(@router_ip, @username, :password => @password)
  end

  def reset
    # zero-out the bandwidth count for all ips
    session.exec!('iptables -Z traffic_out')
    session.exec!('iptables -Z traffic_in')
    puts "Reset traffic stats."
  end
  
  def disconnect
    @session.close if @session
    @session = nil
    @configured = false
  end
    
  def setup(router_ip, username, password, ips)
    return if @configured
    @router_ip = router_ip
    @username = username
    @password = password
    
    # initial setup
    setup_commands = [
      "iptables -N traffic_in",
      "iptables -N traffic_out",      
      "iptables -I FORWARD 1 -j traffic_in",
      "iptables -I FORWARD 2 -j traffic_out"
      #"iptables -I FORWARD -i eth0 -j traffic_in",
      #"iptables -I FORWARD -o eth0 -j traffic_out"
    ]
    setup_commands.each { |cmd| session.exec!(cmd) }
    
    # per-ip monitoring
    ips.each do |ip|
      # delete ip before put in the chain if already exists
      session.exec!("iptables -D traffic_in -d #{ip}")
      session.exec!("iptables -D traffic_out -s #{ip}")
      # put ip in the chain
      session.exec!("iptables -A traffic_in -d #{ip}")
      session.exec!("iptables -A traffic_out -s #{ip}")
    end
    @configured = true
  end

  #private
  
  def retrieve_iptables_stats(ingress=true)
    direction = ingress ? 'in' : 'out'
    iptables_output = session.exec!( "iptables -L traffic_#{direction} -vnx;date -u +%c")
    parse_iptables_stats( iptables_output, ingress)
  end

  def parse_iptables_stats(dump, ingress=true)
    ip_column = ingress ? 7 : 6
    traffic = {}
    lines = dump.split(/\n/)
    lines.each do |line|
      line = line.split("\s")
  
      # create hash of ips with their corresponding traffic
      traffic[ line[ip_column] ] = line[1].to_i if line[ip_column] =~ /\d.\d.\d.\d/
    end
    [Time.parse(lines.last),traffic]
  end

end
