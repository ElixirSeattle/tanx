tool "launch" do
  flag :base_port, accept: Integer, default: 4000

  include :exec, exit_on_nonzero_status: true
  include :gems
  include :terminal

  def nodename(port)
    "tanxport-#{port}@localhost"
  end

  def start(port = nil)
    unless port
      port = base_port
      port += 1 while @controllers.key?(port)
    end
    if @controllers.key?(port)
      puts("Port #{port} is already running.", :bold, :red)
    else
      start!(port)
    end
  end

  def start!(port)
    cmd = ["elixir", "--sname", nodename(port), "-S", "mix", "phx.server"]
    env = {"PORT" => port.to_s}
    unless @controllers.empty?
      env["TANX_CONNECT_NODE"] = nodename(@controllers.keys.first)
    end
    controller = exec(cmd, env: env, background: true, out: :controller)
    spinner(leading_text: "Starting port #{port} with pid #{controller.pid} ...",
            final_text: "Done\n") do
      loop do
        if controller.out.gets =~ /Running TanxWeb\.Endpoint/
          controller.redirect_out("tmp/#{port}.log", "a")
          break
        end
      end
    end
    @controllers[port] = controller
  end

  def kill(port)
    if @controllers.key?(port)
      controller = @controllers[port]
      spinner(leading_text: "Killing port #{port} with pid #{controller.pid} ...",
              final_text: "Done\n") do
        controller.kill("SIGTERM")
        begin
          loop do
            controller.kill(0)
            sleep(0.2)
          end
        rescue ::Errno::ESRCH
          # Done
        end
      end
      @controllers.delete(port)
    else
      puts("Port #{port} is not running.", :bold, :red)
    end
  end

  def killall
    if @controllers.empty?
      puts("No ports are running.", :bold, :red)
    else
      @controllers.each do |port, controller|
        puts("Killing port #{port} with pid #{controller.pid} ...")
        controller.kill("SIGTERM")
      end
      spinner(leading_text: "Waiting for completion ...",
              final_text: "Done\n") do
        @controllers.each do |port, controller|
          begin
            loop do
              controller.kill(0)
              sleep(0.2)
            end
          rescue ::Errno::ESRCH
            # Done
          end
        end
      end
      @controllers = {}
    end
  end

  def quit
    killall
    puts("EXITING", :bold)
    exit
  end

  def run
    gem "tty-prompt", "~> 0.16"
    require "tty-prompt"
    prompt = TTY::Prompt.new

    exec(["mix", "compile"])
    @controllers = {}

    start
    loop do
      puts("\nCurrent ports: #{@controllers.keys.sort.inspect}", :bold)
      choices = ["Start port"] +
                @controllers.keys.sort.map{ |p| "Kill port #{p}" } +
                ["Kill all", "Quit"]
      choice = prompt.select("What now?", choices)
      case choice
      when /Kill port (\d+)/
        kill($1.to_i)
      when /Kill all/
        killall
      when /Start port/
        start
      when /Quit/
        quit
      else
        puts("Unrecognized choice: #{choice.inspect}", :bold, :red)
      end
    end
  end
end

tool "deploy" do
  flag :project, "--project=VALUE", "-p VALUE"
  flag :tag, "--tag=VALUE", "-t VALUE", default: ::Time.now.strftime("%Y-%m-%d-%H%M%S")
  flag :name, "--name=VALUE", "-n VALUE", default: "tanx"
  flag :ip_addr, "--ip-addr=VALUE", "--ip=VALUE"
  flag :yes, "--yes", "-y"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def run
    project = get(:project) || capture(["gcloud", "config", "get-value", "project"]).strip
    image = "gcr.io/#{project}/#{name}:#{tag}"
    exit(1) unless yes || confirm("Build #{image} and deploy to GKE in project #{project}?", default: true)

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
