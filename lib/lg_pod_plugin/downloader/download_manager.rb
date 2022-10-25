require 'singleton'

module LgPodPlugin

  class LDownloadManager
    include Singleton
    attr_accessor :pool
    attr_reader :rw_lock
    @instance_mutex = Mutex.new

    private_class_method :new
    def initialize
      @rw_lock = Mutex.new
      self.pool = Array.new
    end

    def add_operation(&block)
      thread = Thread.new &block
      self.pool.append(thread)
    end

    def wait_for_finished
      self.pool.each(&:join)
    end
    
    def synchronize(&block)
      @rw_lock.synchronize &block
    end

    def lock
      @rw_lock.lock
    end

    def unlock
      @rw_lock.unlock
    end

    def try_lock
      return @rw_lock.try_lock
    end

    def done
      self.pool.reject! { true  }
    end

    def self.shared
      return @instance if @instance
      @instance_mutex.synchronize do
        @instance ||= new
      end
      @instance
    end
    
  end

end
