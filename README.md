<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-4.20.2-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is a lightweight runtime for building capable AI systems in Ruby.
<br>

It is also the most capable AI Ruby runtime that exists _today_, and that claim is
backed up by research. Maybe it won't always be true, and that would be good news too -
because it would mean the Ruby ecosystem is getting stronger.

llm.rb is not just an API wrapper: it gives you one runtime for providers,
contexts, agents, tools, skills, MCP servers, streaming, schemas, files, and
persisted state, so real systems can be built out of one coherent execution
model instead of a pile of adapters.

llm.rb is designed for Ruby, and although it works great in Rails, it is not tightly
coupled to it. It runs on the standard library by default (zero dependencies),
loads optional pieces only when needed, includes built-in ActiveRecord support through
`acts_as_llm` and `acts_as_agent`, includes built-in Sequel support through
`plugin :llm` and `plugin :agent`, and is designed for engineers who want control over
long-lived, tool-capable, stateful AI workflows instead of just
request/response helpers.

Want to see some code? Jump to [the examples](#examples) section. <br>
Want a taste of what llm.rb can build? See [the screencast](#screencast).

## Architecture

<p align="center">
  <img src="https://github.com/llmrb/llm.rb/raw/main/resources/architecture.png" alt="llm.rb architecture" width="790">
</p>

## Core Concept

[`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html)
is the execution boundary in llm.rb.

It holds:
- message history
- tool state
- schemas
- streaming configuration
- usage and cost tracking

Instead of switching abstractions for each feature, everything builds on the
same context object.

## Differentiators

### Execution Model

- **A system layer, not just an API wrapper** <br>
  Put providers, tools, MCP servers, and application APIs behind one runtime
  model instead of stitching them together by hand.
- **Contexts are central** <br>
  Keep history, tools, schema, usage, persistence, and execution state in one
  place instead of spreading them across your app.
- **Contexts can be serialized** <br>
  Save and restore live state for jobs, databases, retries, or long-running
  workflows.

### Runtime Behavior

- **Streaming and tool execution work together** <br>
  Start tool work while output is still streaming so you can hide latency
  instead of waiting for turns to finish.
- **Agents auto-manage tool execution** <br>
  Use `LLM::Agent` when you want the same stateful runtime surface as
  `LLM::Context`, but with tool loops executed automatically according to a
  configured concurrency mode such as `:call`, `:thread`, `:task`, `:fiber`,
  or experimental `:ractor` support for class-based tools. MCP tools are not
  supported by the current `:ractor` mode, but mixed tool sets can still
  route MCP tools and local tools through different strategies at runtime.
- **Tool calls have an explicit lifecycle** <br>
  A tool call can be executed, cancelled through
  [`LLM::Function#cancel`](https://0x1eef.github.io/x/llm.rb/LLM/Function.html#cancel-instance_method),
  or left unresolved for manual handling, but the normal runtime contract is
  still that a model-issued tool request is answered with a tool return.
- **Requests can be interrupted cleanly** <br>
  Stop in-flight provider work through the same runtime instead of treating
  cancellation as a separate concern.
  [`LLM::Context#cancel!`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html#cancel-21-instance_method)
  is inspired by Go's context cancellation model.
- **Concurrency is a first-class feature** <br>
  Use threads, fibers, async tasks, or experimental ractors without
  rewriting your tool layer. The current `:ractor` mode is for class-based
  tools and does not support MCP tools, but mixed workloads can branch on
  `tool.mcp?` and choose a supported strategy per tool. `:ractor` is
  especially useful for CPU-bound tools, while `:task`, `:fiber`, or
  `:thread` may be a better fit for I/O-bound work.
- **Advanced workloads are built in, not bolted on** <br>
  Streaming, concurrent tool execution, persistence, tracing, and MCP support
  all fit the same runtime model.

### Integration

- **MCP is built in** <br>
  Connect to MCP servers over stdio or HTTP without bolting on a separate
  integration stack.
- **ActiveRecord and Sequel persistence are built in** <br>
  llm.rb includes built-in ActiveRecord support through `acts_as_llm` and
  `acts_as_agent`, plus built-in Sequel support through `plugin :llm` and
  `plugin :agent`.
  Use `acts_as_llm` when you want to wrap `LLM::Context`, `acts_as_agent`
  when you want to wrap `LLM::Agent`, `plugin :llm` when you want a
  `LLM::Context` on a Sequel model, or `plugin :agent` when you want an
  `LLM::Agent`. These integrations support `provider:` and `context:` hooks,
  plus `format: :string` for text columns or `format: :jsonb` for native
  PostgreSQL JSON storage when ORM JSON typecasting support is enabled.
- **ORM models can become persistent agents** <br>
  Turn an ActiveRecord or Sequel model into an agent-capable model with
  built-in persistence, stored on the same table, with `jsonb` support when
  your ORM and database support native JSON columns.
- **Persistent HTTP pooling is shared process-wide** <br>
  When enabled, separate
  [`LLM::Provider`](https://0x1eef.github.io/x/llm.rb/LLM/Provider.html)
  instances with the same endpoint settings can share one persistent
  pool, and separate HTTP
  [`LLM::MCP`](https://0x1eef.github.io/x/llm.rb/LLM/MCP.html)
  instances can do the same, instead of each object creating its own
  isolated per-instance transport.
- **OpenAI-compatible gateways are supported** <br>
  Target OpenAI-compatible services such as DeepInfra and OpenRouter, as well
  as proxies and self-hosted servers, with `host:` and `base_path:` when they
  preserve OpenAI request shapes but change the API root path.
- **Provider support is broad** <br>
  Work with OpenAI, OpenAI-compatible endpoints, Anthropic, Google, DeepSeek,
  Z.ai, xAI, llama.cpp, and Ollama through the same runtime.
- **Tools are explicit** <br>
  Run local tools, provider-native tools, and MCP tools through the same path
  with fewer special cases.
- **Skills are just tools loaded from directories** <br>
  Point llm.rb at directories with a `SKILL.md`, resolve named tools through
  the registry, and run those skills through `LLM::Context` or `LLM::Agent`
  without creating a second execution model. If you are familiar with skills
  in Claude or Codex, llm.rb supports the same general idea.
- **Providers are normalized, not flattened** <br>
  Share one API surface across providers without losing access to provider-
  specific capabilities where they matter.
- **Responses keep a uniform shape** <br>
  Provider calls return
  [`LLM::Response`](https://0x1eef.github.io/x/llm.rb/LLM/Response.html)
  objects as a common base shape, then extend them with endpoint- or
  provider-specific behavior when needed.
- **Low-level access is still there** <br>
  Normalized responses still keep the raw `Net::HTTPResponse` available when
  you need headers, status, or other HTTP details.
- **Local model metadata is included** <br>
  Model capabilities, pricing, and limits are available locally without extra
  API calls.

### Design Philosophy

- **Runs on the stdlib** <br>
  Start with Ruby's standard library and add extra dependencies only when you
  need them.
- **It is highly pluggable** <br>
  Add tools, swap providers, change JSON backends, plug in tracing, or layer
  internal APIs and MCP servers into the same execution path.
- **It scales from scripts to long-lived systems** <br>
  The same primitives work for one-off scripts, background jobs, and more
  demanding application workloads with streaming, persistence, and tracing.
- **Thread boundaries are clear** <br>
  Providers are shareable. Contexts are stateful and should stay thread-local.

## Capabilities

- **Chat & Contexts** — stateless and stateful interactions with persistence
- **Context Serialization** — save and restore state across processes or time
- **Streaming** — visible output, reasoning output, tool-call events
- **Request Interruption** — stop in-flight provider work cleanly
- **Tool Calling** — class-based tools and closure-based functions
- **Run Tools While Streaming** — overlap model output with tool latency
- **Concurrent Execution** — threads, async tasks, and fibers
- **Agents** — reusable assistants with tool auto-execution
- **Skills** — directory-backed capabilities loaded from `SKILL.md`
- **Structured Outputs** — JSON Schema-based responses
- **Responses API** — stateful response workflows where providers support them
- **MCP Support** — stdio and HTTP MCP clients with prompt and tool support
- **Multimodal Inputs** — text, images, audio, documents, URLs
- **Audio** — speech generation, transcription, translation
- **Images** — generation and editing
- **Files API** — upload and reference files in prompts
- **Embeddings** — vector generation for search and RAG
- **Vector Stores** — retrieval workflows
- **Cost Tracking** — local cost estimation without extra API calls
- **Observability** — tracing, logging, telemetry
- **Model Registry** — local metadata for capabilities, limits, pricing
- **Persistent HTTP** — optional connection pooling for providers and MCP

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

#### Streaming

This example uses [`LLM::Stream`](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html) directly so visible output and tool execution can happen together. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"

class Stream < LLM::Stream
  def on_content(content)
    $stdout << content
  end

  def on_tool_call(tool, error)
    return queue << error if error
    $stdout << "\nRunning tool #{tool.name}...\n"
    queue << tool.spawn(:thread)
  end

  def on_tool_return(tool, result)
    if result.error?
      $stdout << "Tool #{tool.name} failed\n"
    else
      $stdout << "Finished tool #{tool.name}\n"
    end
  end
end

llm = LLM.openai(key: ENV["KEY"])
ctx = LLM::Context.new(llm, stream: Stream.new, tools: [System])

ctx.talk("Run `date` and `uname -a`.")
ctx.talk(ctx.wait(:thread)) while ctx.functions.any?
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
end

STDIN.getch
ctx.interrupt!
worker.join
```

#### Sequel (ORM)

The `plugin :llm` integration wraps [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html) on a `Sequel::Model` and keeps tool execution explicit. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "net/http/persistent"
require "sequel"
require "sequel/plugins/llm"

class Context < Sequel::Model
  plugin :llm, provider: -> { { key: ENV["#{provider.upcase}_SECRET"], persistent: true } }
end

ctx = Context.create(provider: "openai", model: "gpt-5.4-mini")
ctx.talk("Remember that my favorite language is Ruby")
puts ctx.talk("What is my favorite language?").content
```

#### ActiveRecord (ORM): acts_as_llm

The `acts_as_llm` method wraps [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html) and
provides full control over tool execution. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "net/http/persistent"
require "active_record"
require "llm/active_record"

class Context < ApplicationRecord
  acts_as_llm provider: -> { { key: ENV["#{provider.upcase}_SECRET"], persistent: true } }
end

ctx = Context.create!(provider: "openai", model: "gpt-5.4-mini")
ctx.talk("Remember that my favorite language is Ruby")
puts ctx.talk("What is my favorite language?").content
```

#### ActiveRecord (ORM): acts_as_agent

The `acts_as_agent` method wraps [`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html) and
manages tool execution for you. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "net/http/persistent"
require "active_record"
require "llm/active_record"

class Ticket < ApplicationRecord
  acts_as_agent provider: :set_provider do
    model "gpt-5.4-mini"
    instructions "You are a concise support assistant."
    tools SearchDocs, Escalate
    concurrency :thread
  end

  private

  def set_provider
    { key: ENV["#{provider.upcase}_SECRET"], persistent: true }
  end
end

ticket = Ticket.create!(provider: "openai", model: "gpt-5.4-mini")
puts ticket.talk("How do I rotate my API key?").content
```

#### Agent

This example uses [`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html) directly and lets the agent manage tool execution. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"

class ShellAgent < LLM::Agent
  model "gpt-5.4-mini"
  instructions "You are a Linux system assistant."
  tools Shell
  concurrency :thread
end

llm = LLM.openai(key: ENV["KEY"])
agent = ShellAgent.new(llm)
puts agent.talk("What time is it on this system?").content
```

#### Skills

This example uses [`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html) with directory-backed skills so `SKILL.md` capabilities run through the normal tool path. If you have used skills in Claude or Codex, this is the same kind of building block. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"

class Agent < LLM::Agent
  model "gpt-5.4-mini"
  instructions "You are a concise release assistant."
  skills "./skills/release", "./skills/review"
end

llm = LLM.openai(key: ENV["KEY"])
puts Agent.new(llm).talk("Use the review skill.").content
```

#### MCP

This example uses [`LLM::MCP`](https://0x1eef.github.io/x/llm.rb/LLM/MCP.html) over HTTP so remote GitHub MCP tools run through the same `LLM::Context` tool path as local tools. See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

```ruby
require "llm"
require "net/http/persistent"

llm = LLM.openai(key: ENV["KEY"])
mcp = LLM::MCP.http(
  url: "https://api.githubcopilot.com/mcp/",
  headers: {"Authorization" => "Bearer #{ENV.fetch("GITHUB_PAT")}"}
).persistent

begin
  mcp.start
  ctx = LLM::Context.new(llm, stream: $stdout, tools: mcp.tools)
  ctx.talk("Pull information about my GitHub account.")
  ctx.talk(ctx.call(:functions)) while ctx.functions.any?
ensure
  mcp.stop
end
```

## Screencast

This screencast was built on an older version of llm.rb, but it still shows
how capable the runtime can be in a real application:

[![Watch the llm.rb screencast](https://img.youtube.com/vi/Jb7LNUYlCf4/maxresdefault.jpg)](https://www.youtube.com/watch?v=x1K4wMeO_QA)

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
