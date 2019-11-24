# Cloudtasker Unique Jobs

**Note**: this extension requires redis

The Cloudtasker batch job extension allows to add sub-jobs to regular jobs. This adds the ability to enqueue a list of jobs and track their overall progression as a groupd of jobs (the batch). This extension allows jobs to define callbacks in their worker to track completion of the batch and take action based on that.

## Configuration

You can enable batch jobs by adding the following to your cloudtasker initializer:
```ruby
# The batch job extension is optional and must be explicitly required
require 'cloudtasker/batch_job'

Cloudtasker.configure do |config|
  # Specify your redis url.
  # Defaults to `redis://localhost:6379/0` if unspecified
  config.redis = { url: 'redis://some-host:6379/0' }
end
```

## Example

The following example defines a worker that adds itself to the batch with different arguments then monitors the success of the batch.

```ruby
class BatchWorker
  include Cloudtasker::Worker

  def perform(level, instance)
    3.times { |n| batch.add(self.class, level + 1, n) } if level < 2
  end

  # Invoked when any descendant (e.g. sub-sub job) is complete
  def on_batch_node_complete(child)
    logger.info("Direct or Indirect child complete: #{child.job_id}")
  end

  # Invoked when a direct descendant is complete
  def on_child_complete(child)
    logger.info("Direct child complete: #{child.job_id}")
  end

  # Invoked when all chidren have finished
  def on_batch_complete
    Rails.logger.info("Batch complete")
  end
end
```

## Available callbacks

The following callbacks are available on your workers to track the progress of the batch:

| Callback | Argument | Description |
|------|-------------|-----------|
| `on_batch_node_complete` | `The child job` | Invoked when any descendant (e.g. sub-sub job) is complete   |
| `on_child_complete` | `The child job` | Invoked when a direct descendant is complete   |
| `on_batch_complete` | none | Invoked when all chidren have finished   |