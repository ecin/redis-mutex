require "forwardable"
require "redis"

class Redis::WithScriptCaching
  extend Forwardable

  def_delegators :@redis, :respond_to?

  def initialize(redis)
    @redis = redis
    @cache = Hash.new { |cache, script| cache[script] = redis.script(:load, script) }
  end

  def eval(script, keys = [], argv = [])
    @redis.evalsha(@cache[script], keys, argv)
  end

  def method_missing(method_name, *args, &block)
    @redis.__send__(method_name, *args, &block)
  end
end
