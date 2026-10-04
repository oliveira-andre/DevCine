require "rake"

# Runs one of the app's rake tasks inside an example and returns what it
# printed ([stdout, stderr]). Tasks are loaded once per process; each run
# re-enables the task, since Rake otherwise runs a task only once.
module RakeTaskHelpers
  def run_rake(name)
    Rails.application.load_tasks unless Rake::Task.task_defined?(name)
    task = Rake::Task[name]
    task.reenable
    out = StringIO.new
    err = StringIO.new
    $stdout = out
    $stderr = err
    task.invoke
    [ out.string, err.string ]
  ensure
    $stdout = STDOUT
    $stderr = STDERR
  end
end

RSpec.configure { |config| config.include RakeTaskHelpers, type: :task }
