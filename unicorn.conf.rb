before_fork do |server, worker|
  old = "/var/run/krecipec.pid.oldbin"
  if File.exists?(old) && server.pid != old
    begin
      Process.kill("QUIT", File.read(old).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

pid "/var/run/krecipec.pid"

preload_app true

stdout_path "/var/log/krecipec.log"
stderr_path "/var/log/krecipec.log"

worker_processes 2

working_directory "/home/rcrowley/www/krecipec"
