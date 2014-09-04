require "redis"
require "securerandom"

class Redis::Mutex

  UNLOCK_SCRIPT = <<-SCRIPT
    if redis.call("get",KEYS[1]) == ARGV[1]
    then
      return redis.call("del",KEYS[1])
    else
      return 0
    end
  SCRIPT

  attr_reader :key, :timeout

  def initialize(redis, key: SecureRandom.hex(16), timeout: 60)
    @redis = redis
    @key = key
    @timeout = timeout
  end

  def lock
    raise ThreadError, "deadlock; recursive locking" if owned?

    until try_lock
      sleep 0.1
    end

    self
  end

  def try_lock
    @redis.set key, signature, nx: true, ex: timeout
  end

  def unlock
    @redis.eval(UNLOCK_SCRIPT, [key], [signature]) == 1
  end

  def locked?
    @redis.get(key) != nil
  end

  def owned?
    @redis.get(key) == signature
  end

  def synchronize
    raise ArgumentError, "must be called with a block" unless block_given?

    lock
    yield
  ensure
    unlock
  end

  private

  def signature
    @signature ||= SecureRandom.uuid
  end
end
