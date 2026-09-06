namespace :rubymcp do
  namespace :clients do
    desc 'Synchronise config/rubymcp_clients.yml with Doorkeeper'
    task sync: :environment do
      require 'rubymcp/client_registry'

      RubyMCP::ClientRegistry.new(Rails.root.join('config/rubymcp_clients.yml')).sync!.each do |key, client_id|
        puts "#{key}: #{client_id}"
      end
    end
  end
end
