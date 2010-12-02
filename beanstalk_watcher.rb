require 'rubygems'
require 'sinatra'
require 'beanstalk-client'

DEFAULT_BEANSTALK_PORT = 11300

get '/' do
  out = ""
  ["/beanstalk_tubes", "/beanstalk_jobs_ready", "/beanstalk_tube_stats"].each do |path|
    out += "<a href='#{path}'>#{path}</a><br />"
  end
  out
end

get '/beanstalk_jobs_ready' do
  if params[:host].nil? || params[:tube].nil?
    status 404
    return "You must provide the following values: host, tube. Optionally, you can also provide: fail_threshold, port, raw"
  end

  host, fail_threshold, tube, port, raw = params[:host], params[:fail_threshold], params[:tube], params[:port] || DEFAULT_BEANSTALK_PORT, (params[:raw].to_s.to_bool)

  # Query beanstalkd
  begin
    stats = beanstalk_stats(host, port, tube)
  rescue Beanstalk::NotFoundError
    status 404
    return "ERROR: Tube not found"
  rescue SocketError, Errno::ECONNREFUSED
    status 404
    return "ERROR: Connection refused"
  end

  jobs_ready = stats["current-jobs-ready"]

  over_threshold = fail_threshold != nil && jobs_ready >= fail_threshold.to_i
  status(500) if over_threshold

  if raw
    return "#{jobs_ready}"
  else
    out = ""
    out += "<h1>OVER THRESHOLD!</h1>" if over_threshold
    out += "current-jobs-ready: #{jobs_ready}"
    return out
  end
end

get '/beanstalk_tube_stats' do
  if params[:host].nil? || params[:tube].nil?
    status 404
    return "You must provide the following values: host, tube. Optionally, you can also provide: port."
  end

  host, tube, port = params[:host], params[:tube], params[:port] || DEFAULT_BEANSTALK_PORT

  begin
    stats = beanstalk_stats(host, port, tube)
    out = "<font size='+2'>"
    stats.each_pair { |k,v| out += "<strong>#{k}:</strong> #{v}<br />" }
    out += "</font>"
    return "<code>#{out}</code>"
  rescue Beanstalk::NotFoundError
    status 404
    return "ERROR: Tube not found"
  rescue SocketError, Errno::ECONNREFUSED
    status 404
    return "ERROR: Connection refused"
  end
end

get '/beanstalk_tubes' do
  if params[:host].nil?
    status 404
    return "You must provide the following values: host, tube. Optionally, you can also provide: port."
  end
  host, tube, port = params[:host], params[:tube], params[:port] || DEFAULT_BEANSTALK_PORT

  conn = beanstalk_connection(host, port)
  tubes = conn.list_tubes.values[0]

  out = "<font face='arial' size='+2'><ul>"

  tubes.each do |t|
    out += "<li><a href='/beanstalk_tube_stats?host=#{params[:host]}&tube=#{t}'>#{t}</a></li>"
    out += ""
  end
  out += "</ul></font>"
  out
end


## HELPERS
class String
  def to_bool
    value = self.clone.strip
    if value =~ /^true$/ || value == "1"
      true
    else
      false
    end
  end
end

def beanstalk_stats(host, port, tube)
  beanstalk = beanstalk_connection(host, port)
  beanstalk.stats_tube(tube)
end

def beanstalk_connection(host, port)
  Beanstalk::Pool.new(["#{host}:#{port}"])
end
