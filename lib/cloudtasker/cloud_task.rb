# frozen_string_literal: true

module Cloudtasker
  # An interface class to manage tasks on the backend (Cloud Task or Redis)
  class CloudTask
    attr_accessor :id, :http_request, :schedule_time, :retries, :queue, :dispatch_deadline

    #
    # The backend to use for cloud tasks.
    #
    # @return [
    #   Backend::MemoryTask,
    #   Cloudtasker::Backend::GoogleCloudTaskV1,
    #   Cloudtasker::Backend::GoogleCloudTaskV2,
    #   Cloudtasker::Backend::RedisTask
    # ] The cloud task backend.
    #
    def self.backend
      # Re-evaluate backend every time if testing mode enabled
      @backend = nil if defined?(Cloudtasker::Testing)

      @backend ||= begin
        if defined?(Cloudtasker::Testing) && Cloudtasker::Testing.in_memory?
          require 'cloudtasker/backend/memory_task'
          Backend::MemoryTask
        elsif Cloudtasker.config.mode.to_sym == :development
          require 'cloudtasker/backend/redis_task'
          Backend::RedisTask
        else
          gct_backend
        end
      end
    end

    #
    # Return the GoogleCloudTaskV* backend to use based on the version
    # of the currently installed google-cloud-tasks gem
    #
    # @return [
    #   Cloudtasker::Backend::GoogleCloudTaskV1,
    #   Cloudtasker::Backend::GoogleCloudTaskV2
    # ] The google cloud task backend.
    #
    def self.gct_backend
      @gct_backend ||= begin
        if !defined?(Google::Cloud::Tasks::VERSION) || Google::Cloud::Tasks::VERSION < '2'
          require 'cloudtasker/backend/google_cloud_task_v1'
          Backend::GoogleCloudTaskV1
        else
          require 'cloudtasker/backend/google_cloud_task_v2'
          Backend::GoogleCloudTaskV2
        end
      end
    end

    #
    # Create the google cloud task queue based on provided parameters if it does not exist already.
    #
    # @param [String] :name The queue name
    # @param [Integer] :concurrency The queue concurrency
    # @param [Integer] :retries The number of retries for the queue
    #
    # @return [Google::Cloud::Tasks::V2::Queue, Google::Cloud::Tasks::V2beta3::Queue] The queue
    #
    def self.setup_production_queue(**kwargs)
      gct_backend.setup_queue(**kwargs)
    end

    #
    # Find a cloud task by id.
    #
    # @param [String] id The id of the task.
    #
    # @return [Cloudtasker::Cloudtask] The task.
    #
    def self.find(id)
      payload = backend.find(id)&.to_h
      payload ? new(**payload) : nil
    end

    #
    # Create a new cloud task.
    #
    # @param [Hash] payload Thee task payload
    #
    # @return [Cloudtasker::CloudTask] The created task.
    #
    def self.create(payload)
      raise MaxTaskSizeExceededError if payload.to_json.bytesize > Config::MAX_TASK_SIZE

      resp = backend.create(payload)&.to_h
      resp ? new(**resp) : nil
    end

    #
    # Delete a cloud task by id.
    #
    # @param [String] id The task id.
    #
    def self.delete(id)
      backend.delete(id)
    end

    #
    # Build a new instance of the class using a backend response
    # payload.
    #
    # @param [String] id The task id.
    # @param [Hash] http_request The content of the http request.
    # @param [Integer] schedule_time When to run the job (Unix timestamp)
    # @param [Integer] retries The number of times the job failed.
    # @param [String] queue The queue the task is in.
    #
    def initialize(id:, http_request:, schedule_time: nil, retries: 0, queue: nil, dispatch_deadline: nil)
      @id = id
      @http_request = http_request
      @schedule_time = schedule_time
      @retries = retries || 0
      @queue = queue
      @dispatch_deadline = dispatch_deadline
    end

    #
    # Equality operator.
    #
    # @param [Any] other The object to compare.
    #
    # @return [Boolean] True if the object is equal.
    #
    def ==(other)
      other.is_a?(self.class) && other.id == id
    end
  end
end
