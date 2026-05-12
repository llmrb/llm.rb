<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-8.1.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is Ruby's most capable AI runtime.

It runs on Ruby's standard library by default. loads optional pieces
only when needed, and offers a single runtime for providers, agents,
tools, skills, MCP, streaming, files, and persisted state. As a bonus,
llm.rb is also [available for mruby](https://github.com/llmrb/mruby-llm).

It supports OpenAI, OpenAI-compatible endpoints, Anthropic, Google
Gemini, DeepSeek, xAI, Z.ai, AWS Bedrock, Ollama, and llama.cpp. It
also includes built-in ActiveRecord and Sequel support, plus concurrent
tool execution through threads, tasks (via async gem), fibers, ractors,
and fork (via xchan.rb gem).

## Quick start

#### LLM::Context

The
[LLM::Context](https://0x1eef.github.io/x/llm.rb/LLM/Context.html)
object is at the heart of the runtime. Almost all other features build
on top of it. It is a low-level interface to a model, and requires tool
execution to be managed manually. The
[LLM::Agent](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html)
class is almost the same as
[LLM::Context](https://0x1eef.github.io/x/llm.rb/LLM/Context.html)
but it manages tool execution for you - we'll cover agents next:

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: $stdout)
ctx.talk "Hello world"
```

#### LLM::Agent

The
[LLM::Agent](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html)
object is implemented on top of
[LLM::Context](https://0x1eef.github.io/x/llm.rb/LLM/Context.html).
It provides the same interface, but manages tool execution for you. It
also has builtin features such as a loop guard that detects repeated
tool call patterns, and another guard that detects infinite tool call
loops. Both guards advise the model to change course rather than raise
an error:

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
agent = LLM::Agent.new(llm, stream: $stdout)
agent.talk "Hello world"
```

#### Tools

The
[LLM::Tool](https://0x1eef.github.io/x/llm.rb/LLM/Tool.html)
class can be subclassed to implement your own tools that can extend the
abilities of a model:

```ruby
class ReadFile < LLM::Tool
  name "read-file"
  description "Read a file"
  parameter :path, String, "The filename or path"
  required %i[path]

  def call(path:)
    {contents: File.read(path)}
  end
end
```

#### MCP

The
[LLM::MCP](https://0x1eef.github.io/x/llm.rb/LLM/MCP.html)
object lets llm.rb use tools provided by an MCP server. Those tools are
exposed through the same runtime as local tools, so you can pass them
to either
[LLM::Context](https://0x1eef.github.io/x/llm.rb/LLM/Context.html)
or
[LLM::Agent](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html).
In this example, the MCP server runs over stdio and
[LLM::Context](https://0x1eef.github.io/x/llm.rb/LLM/Context.html)
uses the same tool loop as local tools:

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
mcp = LLM::MCP.stdio(argv: ["ruby", "server.rb"])

mcp.run do
  ctx = LLM::Context.new(llm, stream: $stdout, tools: mcp.tools)
  ctx.talk "Use the available tools to inspect the environment."
  ctx.talk(ctx.wait(:call)) while ctx.functions?
end
```

#### Skills

Skills are reusable instructions loaded from a `SKILL.md` directory. They let
you package behavior and tool access together, and they plug into the same
runtime as tools, agents, and MCP. When a skill runs, llm.rb spawns a
subagent with the skill instructions, access to only the tools listed in the
skill, and recent conversation context:

```yaml
---
name: release
description: Prepare a release
tools: ["search-docs", "git"]
---

## Task

Review the release state, summarize what changed, and prepare the release.
```

```ruby
require "llm"

class ReleaseAgent < LLM::Agent
  model "gpt-5.4-mini"
  skills "./skills/release"
end

llm = LLM.openai(key: ENV["KEY"])
ReleaseAgent.new(llm, stream: $stdout).talk("Prepare the next release.")
```

#### LLM::Stream

The
[LLM::Stream](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html)
object lets you observe output and runtime events as they happen. You
can subclass it to handle streamed content in your own application:

```ruby
require "llm"

class Stream < LLM::Stream
  def on_content(content)
    $stdout << content
  end
end

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: Stream.new)
ctx.talk "Write a haiku about Ruby."
```

#### LLM::Stream (advanced)

The
[LLM::Stream](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html)
object can also resolve tool calls while output is still streaming. In
`on_tool_call`, you can spawn the tool, push the work onto the stream
queue, and later drain it with `wait`:

```ruby
require "llm"

class Stream < LLM::Stream
  def on_content(content)
    $stdout << content
  end

  def on_tool_call(tool, error)
    return queue << error if error
    queue << ctx.spawn(tool, :thread)
  end
end

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: Stream.new, tools: [ReadFile])
ctx.talk "Read README.md and summarize the quick start."
ctx.talk(ctx.wait) while ctx.functions?
```

#### Concurrency

llm.rb can run tool work concurrently. This is useful when a model calls
multiple tools and you want to resolve them in parallel instead of one
at a time. On
[LLM::Agent](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html),
you can enable this with `concurrency`. Common options are `:call` for
sequential execution, `:thread`, or `:task` for concurrent IO-bound work, and
`:ractor` or `:fork` for more isolated CPU-bound work:

```ruby
require "llm"

class Agent < LLM::Agent
  model "gpt-5.4-mini"
  tools ReadFile
  concurrency :thread
end

llm = LLM.openai(key: ENV["KEY"])
agent = Agent.new(llm, stream: $stdout)
agent.talk "Read README.md and CHANGELOG.md and compare them."
```

#### Serialization

The [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html)
object can be serialized to JSON, which makes it suitable for storing
in a file, a database column, or a Redis queue. The built-in
ActiveRecord and Sequel plugins are built on top of this feature:

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])

# Serialize a context
ctx1 = LLM::Context.new(llm)
ctx1.talk "Remember that my favorite language is Ruby"
string = ctx1.to_json

# Restore a context (from JSON)
ctx2 = LLM::Context.new(llm, stream: $stdout)
ctx2.restore(string:)
ctx2.talk "What is my favorite language?"
```

## Installation

```bash
gem install llm.rb
```

## Examples

#### REPL

This example uses [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html) directly for an interactive REPL. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: $stdout)

loop do
  print "> "
  ctx.talk(STDIN.gets || break)
  puts
end
```

#### Multimodal: Local Files

In llm.rb, a prompt can be a string, an [`LLM::Prompt`](https://0x1eef.github.io/x/llm.rb/LLM/Prompt.html), or an array.
When you use an array, each element can be plain text or a tagged object such as
[`ctx.image_url(...)`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html#image_url-instance_method),
[`ctx.local_file(...)`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html#local_file-instance_method),
or [`ctx.remote_file(...)`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html#remote_file-instance_method).
Those tagged objects carry the metadata the provider adapter needs to turn one
Ruby prompt into the provider-specific multimodal request schema.

`ctx.local_file(path)` tags a local path as a `:local_file` object around
`LLM.File(path)`. If the model understands that file type, you can include it
directly in the prompt array instead of uploading it first through a provider
Files API:

```ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm)
ctx.talk ["Summarize this document.", ctx.local_file("README.md")]
```

#### Context Compaction

This example uses [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html),
[`LLM::Compactor`](https://0x1eef.github.io/x/llm.rb/LLM/Compactor.html), and
[`LLM::Stream`](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html) together so
long-lived contexts can summarize older history and expose the lifecycle
through stream hooks. This approach is inspired by General Intelligence
Systems. The
compactor can also use its own `model:` if you want summarization to run on a
different model from the main context. `token_threshold:` accepts either a
fixed token count or a percentage string like `"90%"`, which resolves
against the active model context window and triggers compaction once total
token usage goes over that percentage. See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"

class Stream < LLM::Stream
  def on_compaction(ctx, compactor)
    puts "Compacting #{ctx.messages.size} messages..."
  end

  def on_compaction_finish(ctx, compactor)
    puts "Compacted to #{ctx.messages.size} messages."
  end
end

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(
  llm,
  stream: Stream.new,
  compactor: {
    token_threshold: "90%",
    retention_window: 8,
    model: "gpt-5.4-mini"
  }
)
```

#### Reasoning

This example uses [`LLM::Stream`](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html) with the OpenAI Responses API so reasoning output is streamed separately from visible assistant output. See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"

class Stream < LLM::Stream
  def on_content(content)
    $stdout << content
  end

  def on_reasoning_content(content)
    $stderr << content
  end
end

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(
  llm,
  model: "gpt-5.4-mini",
  mode: :responses,
  reasoning: {effort: "medium"},
  stream: Stream.new
)
ctx.talk("Solve 17 * 19 and show your work.")
```

#### Request Cancellation

Need to cancel a stream? llm.rb has you covered through [`LLM::Context#interrupt!`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html#interrupt-21-instance_method). <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "io/console"

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: $stdout)
worker = Thread.new do
  ctx.talk("Write a very long essay about network protocols.")
rescue LLM::Interrupt
  puts "Request was interrupted!"
end

STDIN.getch
ctx.interrupt!
worker.join
```

#### Sequel (ORM)

The `plugin :llm` integration wraps [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html) on a `Sequel::Model` and keeps tool execution explicit. Like the ActiveRecord wrappers, its built-in persistence contract is the serialized `data` column, while `provider:` resolves a real `LLM::Provider` instance and `context:` injects defaults such as `model:`. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "net/http/persistent"
require "sequel"
require "sequel/plugins/llm"

class Context < Sequel::Model
  plugin :llm, provider: :set_provider, context: :set_context

  private

  def set_provider
    LLM.openai(key: ENV["OPENAI_SECRET"])
  end

  def set_context
    {model: "gpt-5.4-mini", mode: :responses, store: false}
  end
end

ctx = Context.create
ctx.talk("Remember that my favorite language is Ruby")
puts ctx.talk("What is my favorite language?").content
```

#### ActiveRecord (ORM): acts_as_llm

The `acts_as_llm` method wraps [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html) and
provides full control over tool execution. Its built-in persistence contract is
one serialized `data` column. If your app has provider, model, or usage
columns, provide them to llm.rb through `provider:` and `context:` instead of
relying on reserved wrapper columns.

See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "active_record"
require "llm/active_record"

class Context < ApplicationRecord
  acts_as_llm provider: :set_provider, context: :set_context

  private

  def set_provider
    LLM.openai(key: ENV["OPENAI_SECRET"])
  end

  def set_context
    {model: "gpt-5.4-mini", mode: :responses, store: false}
  end
end

ctx = Context.create!
ctx.talk("Remember that my favorite language is Ruby")
puts ctx.talk("What is my favorite language?").content
```

```ruby
require "llm"
require "active_record"
require "llm/active_record"

class Context < ApplicationRecord
  acts_as_llm provider: :set_provider, context: :set_context

  # Optional application columns can still provide the provider and context.
  # For example, `provider_name` and `model_name` can be normal columns.

  private

  def set_provider
    LLM.public_send(provider_name, key: provider_key)
  end

  def set_context
    {model: model_name, mode: :responses, store: false}
  end
end
```

#### ActiveRecord (ORM): acts_as_agent

The `acts_as_agent` method wraps [`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html) and
manages tool execution for you. Like `acts_as_llm`, its built-in persistence
contract is one serialized `data` column. If your app has provider or model
columns, provide them to llm.rb through your hooks and agent DSL.

See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "active_record"
require "llm/active_record"

class Ticket < ApplicationRecord
  acts_as_agent provider: :set_provider, context: :set_context
  model "gpt-5.4-mini"
  instructions "You are a concise support assistant."
  tools SearchDocs, Escalate
  concurrency :thread

  private

  def set_provider
    LLM.openai(key: ENV["OPENAI_SECRET"])
  end

  def set_context
    {mode: :responses, store: false}
  end
end

ticket = Ticket.create!
puts ticket.talk("How do I rotate my API key?").content
```

```ruby
require "llm"
require "active_record"
require "llm/active_record"

class Ticket < ApplicationRecord
  acts_as_agent provider: :set_provider, context: :set_context
  model "gpt-5.4-mini"
  instructions "You are a concise support assistant."

  private

  def set_provider
    LLM.public_send(provider_name, key: provider_key)
  end

  def set_context
    {mode: :responses, store: false}
  end
end
```

#### MCP

This example uses [`LLM::MCP`](https://0x1eef.github.io/x/llm.rb/LLM/MCP.html) over HTTP so remote GitHub MCP tools run through the same `LLM::Context` tool path as local tools. It expects a GitHub token in `ENV["GITHUB_PAT"]`. See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "net/http/persistent"

llm = LLM.openai(key: ENV["KEY"])
mcp = LLM::MCP.http(
  url: "https://api.githubcopilot.com/mcp/",
  headers: {"Authorization" => "Bearer #{ENV["GITHUB_PAT"]}"},
  persistent: true
)

mcp.start
ctx = LLM::Context.new(llm, stream: $stdout, tools: mcp.tools)
ctx.talk("Pull information about my GitHub account.")
ctx.talk(ctx.wait(:call)) while ctx.functions?
mcp.stop
```

For scoped work, `mcp.run do ... end` is shorter and handles cleanup for you:

```ruby
mcp = LLM::MCP.http(
  url: "https://api.githubcopilot.com/mcp/",
  headers: {"Authorization" => "Bearer #{ENV["GITHUB_PAT"]}"},
  persistent: true
)
mcp.run do
  ctx = LLM::Context.new(llm, stream: $stdout, tools: mcp.tools)
  ctx.talk("Pull information about my GitHub account.")
  ctx.talk(ctx.wait(:call)) while ctx.functions?
end
```

## Resources

- [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) and
  [deepdive (markdown)](resources/deepdive.md) are the examples guide.
- [relay](https://github.com/llmrb/relay) shows a real application built on
  top of llm.rb.
- [doc site](https://0x1eef.github.io/x/llm.rb?rebuild=1) has the API docs.

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)
