# Main class
# Interract with packets' API
class Packet < EM::Connection
  def receive_data data
    Console.show data, 'debug'
    length = data.length
    if length >= 2
      packet = JSON.parse(data)
      if checkMasterKey packet['master_key']
        if packet['controller'].nil? || packet['controller'] == 'core'
          case packet['packet_request']
            when 'uninstall_service'
              installation = ScrollInstaller.new(packet['service_id'])
              status = installation.uninstall
              send_data JSON.generate({status: status}) + "\n"
            when 'install' #Install
              Thread.new {
                installation = ScrollInstaller.new(packet['scroll_type'], packet['scroll_name'], packet['scroll_options'])
                id = installation.install
                send_data JSON.generate({status: 'OK', id:id}) + "\n" #Don't forget this shit again !
              }
            when 'start_service' #Start
              ServiceManager.start_service(packet['service_id'])
              send_data JSON.generate({status: 'OK'}) + "\n" #Don't forget this shit again !
            when 'stop_service' #stop
              ServiceManager.stop_service(packet['service_id'])
              send_data JSON.generate({status: 'OK'}) + "\n" #Don't forget this shit again !
            when 'generate_master_key'
              key = SecureRandom.hex
              Configuration.set_config_opt('masterKey', key)
              Configuration.masterKey = key
              send_data JSON.generate({status: 'OK', new_key: key}) + "\n"
            when 'get_cpu'
              cpu_usage = ServiceManager.get_cpu_usage(packet['service_id'])
              if cpu_usage != 'Offline'
                send_data JSON.generate({status: 'OK', cpu_usage: cpu_usage}) + "\n"
              else
                send_data JSON.generate({status: 'Offline'}) + "\n"
              end
            when 'get_ram'
              ram_usage = ServiceManager.get_ram_usage(packet['service_id'])
              if ram_usage != 'Offline'
                send_data JSON.generate({status: 'OK', ram_usage: ram_usage}) + "\n"
              else
                send_data JSON.generate({status: 'Offline'}) + "\n"
              end
            when 'add_linux_user'
              if UsersManager.add_user(packet['username'], packet['password'], packet['group'], packet['shell'], packet['home_directory'])
                send_data JSON.generate({status: 'OK', message: 'User created'}) + "\n"
              else
                send_data JSON.generate({status: 'ERROR', message: 'Error while creating user'}) + "\n"
              end
            when 'get_installed_services'
              send_data JSON.generate({status: 'OK', services: ServiceManager.get_installed_services}) + "\n"
            when 'get_users_and_groups'
              send_data JSON.generate({status: 'OK', users: UsersManager.get_user_list, groups: UsersManager.get_group_list}) + "\n"
            when 'change_root_password'
              if UsersManager.change_password('root', packet['new_password'])
                if UsersManager.change_password('EdenManager', packet['new_password'])
                  send_data JSON.generate({status: 'OK'}) + "\n"
                else
                  send_data JSON.generate({status: 'ERROR', message: 'Can\'t change EdenManager password'}) + "\n"
                end
              else
                send_data JSON.generate({status: 'ERROR', message: 'Can\'t change root password'}) + "\n"
              end
                                                             ### MINECRAFT ###
            when 'install_plugin_minecraft'
              if Minecraft.download_plugin packet['service_id'], packet['plugin_name']
                send_data JSON.generate({status: 'OK'}) + "\n"
              else
                send_data JSON.generate({status: 'ERROR'}) + "\n"
              end
            when 'get_minecraft_config'
              send_data JSON.generate({status: 'OK', config: Minecraft.get_minecraft_config(packet['service_id'])}) + "\n"
            when 'change_minecraft_config'
              Minecraft.change_minecraft_config(packet['service_id'], packet['key'], packet['value'])
              send_data JSON.generate({status: 'OK'}) + "\n"
            when 'update_bukkit'
              if Minecraft.change_bukkit_version packet['service_id'], packet['build_number']
                send_data JSON.generate({status: 'OK'}) + "\n"
              else
                send_data JSON.generate({status: 'ERROR'}) + "\n"
              end
            else
              Console.show "Unknown packet : #{packet}"
              close_connection
          end
        else
          send_data JSON.generate(ControllersManager.get_controller(packet['controller']).parse_request(packet)) + "\n"
        end
      else
        if packet['packet_request'] == 'get_informations'
          master_key_set = true
          if Configuration.masterKey == 'BopMasterKey'
            master_key_set = false
          end
          loadavg = System.get_load_average
          send_data JSON.generate({status: 'OK', is_master_key_set: master_key_set, load_average_1: loadavg[0], load_average_5: loadavg[1], load_average_15: loadavg[2], ram_usage: System.get_memory_usage}) + "\n"
        else
          Console.show "Master key is invalid : #{packet}", 'error'
          close_connection
        end
      end
    else
      Console.show "Just got a wrong packet with length : #{length}", 'error'
      close_connection
    end
  end

  #Check if the measterKey is the same as in config file
  def checkMasterKey masterKey
    return true if masterKey == Configuration.masterKey
    return false
  end
end