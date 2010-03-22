ENABLE_LOG = FALSE

require 'rubygems'
require 'sinatra'
require 'beanstalk_watcher'

root_dir = File.dirname(__FILE__)

set :environment, :production
set :root,  root_dir
set :app_file, File.join(root_dir, 'beanstalk_watcher.rb')
disable :run

if ENABLE_LOG
  FileUtils.mkdir_p 'log' unless File.exists?('log')
  log = File.new("log/sinatra.log", "a")
  $stdout.reopen(log)
  $stderr.reopen(log)
end

run Sinatra::Application