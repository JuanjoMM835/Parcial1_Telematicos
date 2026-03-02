Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/focal64"

  # MAESTRO
  config.vm.define "maestro" do |maestro|
    maestro.vm.hostname = "maestro"
    
    # NAT (internet)
    maestro.vm.network "forwarded_port", guest: 80, host: 8080
    
    # Red privada (comunicación interna)
    maestro.vm.network "private_network", ip: "192.168.56.10"
  end

  # ESCLAVO
  config.vm.define "esclavo" do |esclavo|
    esclavo.vm.hostname = "esclavo"
  
    # NAT automático (internet)
    esclavo.vm.network "forwarded_port", guest: 53, host: 5353
  
    # Red privada (comunicación con maestro)
    esclavo.vm.network "private_network", ip: "192.168.56.11"
    end

end