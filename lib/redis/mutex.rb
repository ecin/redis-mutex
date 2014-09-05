require "redis"
require "securerandom"

# Public: A Redis-backed mutex implementation that is compatible with Ruby's
# standard library Mutex class. Redis::Mutex can be used as a distributed lock;
# multiple processes on different machines can use Redis::Mutex to coordinate their
# actions.
#
# Examples
#
#   redis = Redis.new
#
#   # Redis::Mutex.new creates a mutex with a random key; that is, the key that's inserted
#   # into the Redis server to create the lock will be random.
#   mutex = Redis::Mutex.new(redis)
#   mutex.lock
#   redis.get(mutex.key) # returns a uuid identifying the lock
#
#   # To coordinate across different processes, a predetermined key name is preferable.
#   Redis::Mutex.new(redis, key: "scheduler_lock")
#
#   # Finally, a timeout determines how long the lock is valid for. This guarantees that
#   # the lock will eventually be available, even if the original process that created the
#   # lock disappears.
#   Redis::Mutex.new(redis, key: "scheduler_lock", timeout: 120)
#
#   # Once locked, a Redis::Mutex will be locked until the timeout transpires. The lock can
#   # be refreshed to extend the expiration time of the lock.
#   mutex = Redis::Mutex.new(redis)
#   mutex.lock
#   mutex.refresh # will reset the lock's ttl to mutex.timeout's value
class Redis::Mutex

  UNLOCK_SCRIPT = <<-SCRIPT.freeze
    if redis.call("get",KEYS[1]) == ARGV[1]
    then
      return redis.call("del",KEYS[1])
    else
      return 0
    end
  SCRIPT

  REFRESH_SCRIPT = <<-SCRIPT.freeze
    if redis.call("get",KEYS[1]) == ARGV[1]
    then
      return redis.call("expire",KEYS[1],ARGV[2])
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
    raise ThreadError, "must be called with a block" unless block_given?

    lock
    yield
  ensure
    unlock
  end

  def refresh
    @redis.eval(REFRESH_SCRIPT, [key], [signature, timeout]) == 1
  end

  private

  def signature
    @signature ||= SecureRandom.uuid
  end
end
