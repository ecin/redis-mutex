require "minitest/autorun"
require "minitest/mock"
require "minitest/pride"
require "pry"

require "redis/with_script_caching"

describe Redis::WithScriptCaching do

  before do
    @redis = Minitest::Mock.new
    @script_caching_redis = Redis::WithScriptCaching.new(@redis)
  end

  it "delegates commands to a Redis instance" do
    %w(get set del).each do |command|
      @redis.expect(command, nil)
      @script_caching_redis.__send__(command)
    end

    @redis.verify
  end

  it "loads scripts into a Redis instance and caches the resulting SHA" do
    script = "return 1"
    digest = "abcd1234"
    keys = []
    argv = []
    @redis.expect(:script, digest, [:load, script])
    @redis.expect(:evalsha, 1, [digest, keys, argv])

    @script_caching_redis.eval(script, keys, argv)
    @redis.verify

    # Test caching: since @redis doesn't expect the :script
    # method again, it'll raise an error unless our caching works.
    @redis.expect(:evalsha, 1, [digest, keys, argv])
    @script_caching_redis.eval(script, keys, argv)
    @redis.verify
  end

  it "responds to Redis commands" do
    @script_caching_redis = Redis::WithScriptCaching.new

    %w(get set del).each do |command|
      assert @script_caching_redis.respond_to?(command)
    end
  end

end
