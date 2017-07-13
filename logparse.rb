#!/usr/bin/env ruby

require 'optparse'
require 'digest'
require 'yaml'

CHUNK_SIZE = 2 ** 13 # 8192
TS_RE = /\w{2} \w{3} \d{4} \d{2}:\d{2}:\d{2} \w{3}/
MEM_RE = /(noodoo:memory.*worker \(([0-9])\:.*)/
MEM_RSS_RE = /rss: ([0-9]+)/
MEM_HEAP_TOTAL_RE = /heapTotal: ([0-9]+)/
MEM_HEAP_USED_RE = /heapUsed: ([0-9]+)/
CACHE_TTL = 55

def main
  argv = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("-f", "--logfile path", String, "Log file path") do |p|
      argv[:file] = p
    end

    opts.on("-i", "--worker id", Integer, "Worker ID") do |p|
      argv[:id] = p
    end

    opts.on("-k", "--key keyname", String, "Return specific key value") do |p|
      argv[:key] = p
    end
  end.parse!
  raise OptionParser::MissingArgument if argv[:file].nil?

  stats = {}
  first_run = false
  md5 = Digest::MD5.new
  stats_fname = File.join('/tmp',
    File.basename($0, '.rb') + '-' + md5.hexdigest(argv[:file]) + '.yaml')

  save_stats = ->() {
    # if first_run
    #   stats[:last_read_pos] = 0
    # else
    #   stats[:last_read_pos] = File.size(argv[:file])
    # end
    File.open(stats_fname, 'w') { |f| YAML.dump(stats, f) }
  }

  if !File.file?(stats_fname)
    first_run = true
    stats[:last_read_pos] = 0
    save_stats.call()
  end

  old_stats = YAML.load_file(stats_fname)

  if !first_run && File.mtime(stats_fname) + CACHE_TTL > DateTime.now.to_time
    stats = old_stats
  else
    parser = LogParser.new(argv[:file], stats)
    new_stats = parser.process(old_stats[:last_read_pos].to_i)
    
    # new_stats[:workers].each do |key, val|
    #   old_stats[key] = val
    # end
    
    # old_stats[:last_read_pos] = new_stats[:last_read_pos]

    p old_stats

    stats = old_stats

    save_stats.call()
  end

  if argv[:id] then
    stats = stats[:workers][argv[:id]]
    stats = stats[argv[:key].to_sym] if argv[:key]
  end

  puts stats
end


class LogParser
  def initialize(log_path)
    raise ArgumentError unless File.exists?(log_path)

    @log = File.open(log_path, 'r')
    @buffer_size = CHUNK_SIZE
    @stats = {
      workers: {}
    }
  end

  def process(start_pos)
    # starting from the end, file is constantly growing
    @log.seek(0, IO::SEEK_END)
    @stats[:last_read_pos] = @log.pos #File.size(argv[:file])

    offset = @log.pos
    stop_flag = false
    while offset > start_pos && !stop_flag
      if (offset - @buffer_size) < 0
        to_read = offset
      else
        to_read = @buffer_size
      end

      @log.seek(offset - to_read)
      data = @log.read(to_read)
      offset -= data.length

      self.calc(data, stop_flag)
    end

    # @stats[]
    return @stats
  end

  def calc(data, stop_flag)
    log_items = data.scan(MEM_RE)
    
    log_items.each do |log_item|
      str = log_item[0]
      id = log_item[1].to_i
      
      rss = str[MEM_RSS_RE, 1].to_i
      heap_total = str[MEM_HEAP_TOTAL_RE, 1].to_i
      heap_used = str[MEM_HEAP_USED_RE, 1].to_i
      
      @stats[:workers][id] = {
        rss: rss,
        heapTotal: heap_total,
        heapUsed: heap_used
      }
    end
    
    #stop_flag = true
  end
end

main