require "examine/version"

require 'socket'
require 'thor'

module Examine
  class Error < StandardError; end

  module CLI
    class Clair < Thor
      desc 'start', 'start a clair server'
      def start
        db_pid = spawn 'docker run -d --name clair-db arminc/clair-db:latest'
        puts "clair-db started. (PID: #{db_pid})"

        command = 'docker ps --filter="name=clair-db" --filter="status=running" --filter="expose=5432/tcp" | grep -v CONT'
        print '.' until system(command)

        clair_pid = spawn 'docker run --restart=unless-stopped -p 6060:6060 --link clair-db:postgres -d --name clair arminc/clair-local-scan:latest'
        puts "clair-local-scan started. (PID: #{clair_pid})"
      end

      method_option :ip, desc: 'ip address', default: nil, type: :string
      method_option :clair_url, desc: 'clair url', default: 'http://localhost:6060', type: :string
      desc 'scan <image>', 'scan a specific image'
      def scan(image)
        ip = options[:ip] || Socket.ip_address_list[1].ip_address
        system "docker pull #{image}"
        system "clair-scanner -c #{options[:clair_url]} --ip #{ip} #{image}"
      end

      desc 'status', 'status of clair server'
      def status
        system "docker ps -a | grep clair"
      end

      desc 'stop', 'stop all clair servers'
      def stop
        system "docker stop $(docker ps | grep -v CONT | grep clair- | awk '{ print $1 }')"
        system "docker system prune -f"
      end
    end

    class Application < Thor
      package_name 'examine'

      desc 'clair', 'manage clair'
      subcommand :clair, Examine::CLI::Clair
    end
  end
end
