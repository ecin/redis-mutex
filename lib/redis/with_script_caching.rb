require "delegate"
require "redis"

class Redis::WithScriptCaching < SimpleDelegator

  def initialize(redis)
    @cache = Hash.new { |cache, script| cache[script] = redis.script(:load, script) }
    super
  end

  def eval(script, keys = [], argv = [])
    __getobj__.evalsha(@cache[script], keys, argv)
  end

end
