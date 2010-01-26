require 'net/http'
require 'thread'
require 'fileutils'
require 'tile.rb'

class TileManager

  def initialize(observer)
    @observer = observer
    @queue = Queue.new
    Thread.new do
      loop {new_thread_from_queue if !@queue.empty?}
    end
  end

  def get_tile(x, y, zoom)
    x = wraparound(x, zoom)
    y = wraparound(y, zoom)
    tile = Tile.new(x, y, zoom)
    if File.exist?(tile.path)
      tile.load_image
    else
      dir = File.dirname(tile.path)
      FileUtils.mkdir_p dir if !File.exist?(dir)
      enqueue_for_download(tile)
    end
    tile
  end

  private

  def wraparound(value, zoom)
    max = 2 ** zoom
    value = max - (value.abs % max) if value < 0
    value = value % max if value >= max
    value
  end

  def new_thread_from_queue
    Thread.new do
      tile = @queue.pop
      download(tile)
      tile.load_image
      @observer.tile_loaded(tile)
    end
  end

  def enqueue_for_download(tile)
    puts "enqueued #{tile.url}"
    @queue << tile
  end

  def download(tile)
    uri = URI.parse(tile.url)
    req = Net::HTTP::Get.new(uri.path, {"User-Agent" => "mapcache"})
    res = Net::HTTP.new(uri.host).start {|http| http.request(req)}
    if res.code == "200"
      File.open(tile.path, 'wb') {|f| f.write(res.body)}
    end
  end

end
