namespace :rubymcp do
  namespace :tasks do
    desc 'Delete expired background tasks, including their arguments and results'
    task prune: :environment do
      RubyMCP::Task.where('expires_at <= ?', Time.current).delete_all
    end
  end
end
