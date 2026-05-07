# frozen_string_literal: true

class ReleaseAgent < LLM::Agent
  class Stream < LLM::Stream
    def on_content(content)
      $stdout << content
    end

    def on_tool_call(tool, error)
      queue << (error || ctx.spawn(tool, :thread))
      puts "[tool] call #{tool.name} (error=#{error})"
    end

    def on_tool_return(tool, result)
      puts "[tool] return #{tool.name}"
    end
  end
end
