# Temporary hack: bypass asdf 0.7.0 because its shims are eating signals.
# See https://github.com/asdf-vm/asdf/issues/475
elixir_path = (`asdf which elixir` rescue "").strip
erl_path = (`asdf which erl` rescue "").strip
unless elixir_path.empty? || erl_path.empty?
  elixir_path = ::File.dirname(elixir_path)
  erl_path = ::File.dirname(erl_path)
  ENV["PATH"] = "#{erl_path}:#{elixir_path}:#{ENV['PATH']}"
end

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

tool "predeploy" do
  flag :project, "--project=VALUE", "-p VALUE"
  flag :name, "--name=VALUE", "-n VALUE", default: "tanx"
  flag :yes, "--yes", "-y"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def run
    project = get(:project) || capture(["gcloud", "config", "get-value", "project"]).strip
    exit(1) unless yes || confirm("Prebuild tanx dependencies in #{project}? ", default: true)

    puts("Building base images...", :bold, :cyan)
    exec(["gcloud", "builds", "submit",
          "--project", project,
          "--config", "deploy/build-base.yml",
          "."])
    puts("Done", :bold, :cyan)
  end
end

tool "deploy" do
  flag :project, "--project=VALUE", "-p VALUE"
  flag :tag, "--tag=VALUE", "-t VALUE", default: ::Time.now.strftime("%Y-%m-%d-%H%M%S")
  flag :name, "--name=VALUE", "-n VALUE", default: "tanx"
  flag :yes, "--yes", "-y"

  include :exec, exit_on_nonzero_status: true
  include :terminal

  def run
    project = get(:project) || capture(["gcloud", "config", "get-value", "project"]).strip
    exit(1) unless yes || confirm("Deploy build #{tag} in project #{project}? ", default: true)

    image = "gcr.io/#{project}/#{name}:#{tag}"
    puts("Building image: #{image} ...", :bold, :cyan)
    exec(["gcloud", "builds", "submit",
          "--project", project,
          "--config", "deploy/build-tanx.yml",
          "--substitutions", "_BUILD_ID=#{tag}",
          "."])
    puts("Updating deployment...", :bold, :cyan)
    exec(["kubectl", "set", "image", "deployment/#{name}", "#{name}=#{image}"])
    puts("Done", :bold, :cyan)
  end
end
