require "minitest/autorun"
require "minitest/pride"
require "pry"
require "timeout"

require "redis/mutex"

describe Redis::Mutex do

  before do
    @redis = Redis.new
    @mutex = Redis::Mutex.new(@redis)
  end

  after do
    @doppelganger = nil
    @redis.flushdb
  end

  it "tries to connect to default Redis" do
    assert Redis::Mutex.new.try_lock
  end

  it "can acquire a lock" do
    assert @mutex.try_lock
    refute @redis.get(@mutex.key).nil?, "Redis lock key should be set"
  end

  it "knows if the lock is held" do
    assert @mutex.try_lock
    assert @mutex.locked?
    assert @mutex.owned?

    assert doppelganger.locked?, "mutexes with same key should know if lock is held"
  end

  it "knows if it owns the lock" do
    assert @mutex.try_lock
    assert @mutex.owned?

    refute doppelganger.owned?
  end

  it "raises ThreadError if it already owns the lock" do
    assert @mutex.lock
    assert @mutex.owned?
    assert_raises(ThreadError) { @mutex.lock }
  end

  it "can wait on a lock" do
    assert @mutex.lock

    assert_raises(TimeoutError) do
      Timeout.timeout(1) do
        doppelganger.lock
      end
    end

    refute @redis.get(@mutex.key).nil?, "Redis lock key should be set"
  end

  it "can acquire a lock in a non-blocking way" do
    assert @mutex.try_lock
    refute @mutex.try_lock

    @mutex.unlock
    assert @mutex.try_lock
  end

  it "has an expiration" do
    assert @mutex.try_lock
    assert_in_delta @mutex.timeout, @redis.ttl(@mutex.key), 1, "Redis lock key should expire"
  end

  it "can release a lock" do
    assert @mutex.lock
    assert @mutex.unlock
    assert_nil @redis.get(@mutex.key)
  end

  it "prevents another mutex from acquiring a lock" do
    doppelganger = @mutex.dup

    assert_equal @mutex.key, doppelganger.key

    assert @mutex.try_lock
    refute doppelganger.try_lock, "mutex dup shouldn't acquire lock"

    assert @mutex.unlock
    assert doppelganger.try_lock, "mutex dup should acquire lock"
  end

  it "does not prevent another mutex with a different key from acquiring a lock" do
    different_mutex = Redis::Mutex.new(@redis)

    refute_equal @mutex.key, different_mutex.key

    assert @mutex.try_lock
    assert different_mutex.try_lock, "mutexes with different keys are concurrently lockable"
  end

  it "is unlocked if the Redis lock key expires" do
    assert @mutex.try_lock
    assert @mutex.locked?

    # Expiration is the same as deleting the key
    @redis.del(@mutex.key)
    refute @mutex.locked?
  end

  it "can run a block after obtaining a lock" do
    result = @mutex.synchronize { 1 }
    refute @mutex.locked?
    assert_equal 1, result

    assert @mutex.try_lock
    assert_raises(TimeoutError) do
      Timeout.timeout(1) do
        doppelganger.synchronize { 1 }
      end
    end
  end

  it "can refresh a lock's expiration" do
    assert @mutex.try_lock

    # Reduce TTL of lock key
    @redis.expire(@mutex.key, 10)

    assert @mutex.refresh
    assert_in_delta @mutex.timeout, @redis.ttl(@mutex.key), 1, "Redis lock key should be fresh"
  end

  it "fails to refresh an expired lock" do
    assert @mutex.try_lock

    @redis.del(@mutex.key)

    refute @mutex.refresh
  end

  private

  def doppelganger
    @doppelganger ||= Redis::Mutex.new(@redis, key: @mutex.key)
  end

end
