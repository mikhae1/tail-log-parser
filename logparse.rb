#!/usr/bin/env ruby

require 'time'

class LogParser

  # Regexp to match the timestamps in the apache common log format
  TIME_REGEXP   = /\w{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} \w{3}/

  def initialize(log_path)
    raise ArgumentError unless File.exists?(log_path)

    @log          = File.open(log_path)
    @delta        = 1/24.0 # 1 hour
    @ending_at    = DateTime.now.to_time
    @starting_at  = (DateTime.now - @delta).to_time
  end

  def emit(&block)
    @log.each_line do |line|
      next unless timestamp = line.match(TIME_REGEXP)

      current_time = Time.parse(timestamp[0])

      # puts current_time

      if current_time >= @starting_at && current_time <= @ending_at
        yield line
      end

      if current_time > @ending_at
        return
      end
    end
  end

end

if __FILE__ == $0
  parser = LogParser.new(*ARGV)

  parser.emit {|l| puts l}
end