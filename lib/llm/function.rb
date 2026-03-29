  ##
  # Calls the function in a separate thread.
  #
  # This is the low-level method that powers concurrent tool execution.
  # Prefer the collection methods on {LLM::Session#functions} for most
  # use cases: {LLM::Function::Array#call}, {LLM::Function::Array#wait},
  # or {LLM::Function::Array#spawn}.
  #
  # @example
  #   # Normal usage (via collection)
  #   ses.talk(ses.functions.wait)
  #
  #   # Direct usage (uncommon)
  #   thread = tool.spawn
  #   result = thread.value
  #
  # @return [Thread]
  #   Returns a thread whose {Thread#value} is an {LLM::Function::Return}.
  def spawn
    Thread.new do
      runner = ((Class === @runner) ? @runner.new : @runner)
      Return.new(id, name, runner.call(**arguments))
    rescue => ex
      Return.new(id, name,  {error: true, type: ex.class.name, message: ex.message})
    end
  ensure
    @called = true
  end