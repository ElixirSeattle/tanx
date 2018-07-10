tool "startn" do
  flag :count, accept: Integer, default: 2

  include :exec, exit_on_nonzero_status: true
  include :gems
  include :terminal

  def run
    gem "tty-prompt", "~> 0.16"
    require "tty-prompt"
    prompt = TTY::Prompt.new

    exec(["mix", "compile"])
    controllers = {}
    count.times do |i|
      port = 4000 + i
      cmd = ["elixir", "--sname", "n#{i}@localhost"]
      cmd += ["-e", 'Node.connect :"n0@localhost"'] if i > 0
      cmd += ["-S", "mix", "phx.server"]
      controller = exec(cmd, env: {"PORT" => "#{port}"}, background: true,
                        out: :controller, err: :null)
      spinner(leading_text: "Starting port #{port} with pid #{controller.pid}...",
              final_text: "Done\n") do
        loop do
          if controller.out.gets =~ /compiled\s\d+\sfiles/
            controller.out.close
            break
          end
        end
      end
      controllers[port] = controller
    end

    until controllers.empty?
      puts("\nPorts still alive: #{controllers.keys.inspect}", :bold, :cyan)
      port = prompt.select("Kill which port?", controllers.keys.map(&:to_s) + ["all"])
      if port == "all"
        controllers.each_value{ |c| c.kill("SIGTERM") }
        controllers = {}
      else
        port = port.to_i
        controllers[port].kill("SIGTERM")
        controllers.delete(port)
      end
    end
    puts("All ports killed", :bold)
  end
end

tool "deploy" do
  flag :project, "--project=VALUE", "-p VALUE"
  flag :tag, "--tag=VALUE", "-t VALUE", default: ::Time.now.strftime("%Y-%m-%d-%H%M%S")
  flag :name, "--name=VALUE", "-n VALUE", default: "tanx"
  flag :ip_addr, "--ip-addr=VALUE", "--ip=VALUE"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def run
    project = get(:project) || capture(["gcloud", "config", "get-value", "project"]).strip
    image = "gcr.io/#{project}/#{name}:#{tag}"
    exit(1) unless confirm("Build #{image} and deploy to GKE in project #{project}?", default: true)

    puts("Building image: #{image} ...", :bold, :cyan)
    exec(["gcloud", "container", "builds", "submit",
          "--project", project,
          "--config", "cloudbuild.yaml",
          "--substitutions", "_IMAGE=#{image},_BUILD_ID=#{tag}"])
    if ip_addr
      puts("Creating new deployment...", :bold, :cyan)
      exec(["kubectl", "run", name, "--image", image, "--port", "8080"])
      puts("Creating service...", :bold, :cyan)
      cmd = ["kubectl", "expose", "deployment", name,
             "--type", "LoadBalancer",
             "--port", "80",
             "--target-port", "8080"]
      cmd.concat(["--load-balancer-ip", ip_addr]) unless ip_addr == "new"
      exec(cmd)
    else
      puts("Updating deployment...", :bold, :cyan)
      exec(["kubectl", "set", "image", "deployment/#{name}", "#{name}=#{image}"])
    end
    puts("Done", :bold, :cyan)
  end
end
