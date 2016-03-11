#!/usr/bin/env ruby

require 'time'

TAIL_BUF_LENGTH = 2 ** 13 # 8192
TS_REGEXP = /super\w{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} \w{3}/

class IO
  def tail_hours(hours)
    return [] if hours < 1

    if File.size(self) < TAIL_BUF_LENGTH
      #TAIL_BUF_LENGTH = File.size(self)
      return self.readlines.reverse
    end

    ts_stop = (DateTime.now - (hours/24.0)).to_time

    self.seek(-TAIL_BUF_LENGTH, IO::SEEK_END)

    out = ''
    line_count = 0
    read_count = 0
    begin
      p size
      buf = self.read(TAIL_BUF_LENGTH)
      line_count += buf.count('\n')
      read_count += buf.length
      out += buf

      seek_val = 2 * -TAIL_BUF_LENGTH

      if (self.pos < TAIL_BUF_LENGTH)
        seek_val = -2 * self.pos
      end

      #p self.pos
      # if (self.pos == 0)
      #   p 'End'
      # end

      self.seek(seek_val, IO::SEEK_CUR)

      ts = buf[TS_REGEXP]
      if ts != nil
        cur_time = Time.parse(ts)
      end
      # p 'cur_time: ', cur_time, buf
      # p 'pos: ' + self.pos.to_s
    end while self.pos != 0 && (cur_time == nil || cur_time >= ts_stop)

    return out.split('\n')[-line_count..-1]
  end
end


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
    @log.tail_hours(1)
    # @log.each_line do |line|
    #   next unless timestamp = line.match(TIME_REGEXP)

    #   current_time = Time.parse(timestamp[0])

    #   puts current_time

    #   if current_time >= @starting_at && current_time <= @ending_at
    #     yield line
    #   end

    #   if current_time > @ending_at
    #     return
    #   end
    # end
  end

end

if __FILE__ == $0
  parser = LogParser.new(*ARGV)

  parser.emit {|l| puts l}
end