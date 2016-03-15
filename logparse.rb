#!/usr/bin/env ruby

require 'time'

TAIL_BUF_LENGTH = 2 ** 13 # 8192
TS_RE = /\w{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} \w{3}/
DB_DELAY_RE = /nd-db:time.*([0-9]+\.[0-9]*)ms/

class LogParser
  def initialize(log_path)
    raise ArgumentError unless File.exists?(log_path)

    @log = File.open(log_path, 'r')
    @buffer_size = TAIL_BUF_LENGTH
    @stats = {
      db_count: 0,
      db_avg_delay: 0
    }
  end

  def process(hours)
    delta = hours.to_f/24.0
    ts_stop = (DateTime.now - delta).to_time

    # starting from the end
    @log.seek(0, IO::SEEK_END)
    offset = @log.pos
    stop_flag = false
    data_tail = nil
    while offset > 0 && !stop_flag
      if (offset - @buffer_size) < 0
        to_read = offset
      else
        to_read = @buffer_size
      end

      @log.seek(offset - to_read)
      data = @log.read(to_read)
      offset -= data.length

      data = data + data_tail if data_tail

      last_ts_str = data[TS_RE] # first ts
      data_tail = nil
      if last_ts_str
        data_tail = data[0 ... data.index(last_ts_str)]
        last_ts = Time.parse(last_ts_str)
      end

      # the end of the tail
      if last_ts && last_ts < ts_stop
        # find the stop position
        stop_flag = true;
        match_arr = data.scan(TS_RE)
        part_data = ''
        for i in 0 ... match_arr.size
          ts = Time.parse(match_arr[i])
          if (ts > ts_stop)
            stop_pos = data.index(match_arr[i])
            part_data = data.slice(stop_pos, data.length)
            break
          end
        end
        data = part_data
      end

      self.calc(data)
    end

    # result output
    # @log.seek(offset)
    # return data = @log.read
    puts 'Results:'
    puts "db_records_found\t#{@stats[:db_count]}"
    puts "db_avg_delay\t#{@stats[:db_avg_delay]}"
  end

  def calc(data)
    db_delays = data.scan(DB_DELAY_RE).collect{|i| i[0].to_f}
    return if db_delays.length == 0

    @stats[:db_count] += db_delays.length
    @stats[:db_avg_delay] = (@stats[:db_avg_delay] + db_delays.reduce(:+).to_f / db_delays.length) / 2.0
  end

end

if __FILE__ == $0
  parser = LogParser.new(ARGV[0])
  parser.process(ARGV[1])
end
