<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-8.1.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is the most capable runtime for building AI systems in Ruby.
<br>

llm.rb is designed for Ruby, and although it works great in Rails, it is not tightly
coupled to it. It runs on the standard library by default (zero dependencies),
loads optional pieces only when needed, includes built-in ActiveRecord support through
`acts_as_llm` and `acts_as_agent`, includes built-in Sequel support through
`plugin :llm` and `plugin :agent`, and is designed for engineers who want control over
long-lived, tool-capable, stateful AI workflows instead of just
request/response helpers.

It provides one runtime for providers, agents, tools, skills, MCP servers, streaming,
schemas, files, and persisted state, so real systems can be built out of one coherent
execution model instead of a pile of adapters.

It includes support for OpenAI, OpenAI-compatible endpoints, Anthropic, Google Gemini,
DeepSeek, xAI, Z.ai, AWS Bedrock, Ollama, and llama.cpp.

It provides concurrent tool execution with multiple strategies exposed through a single
runtime: async-task, threads, fibers, ractors and processes (fork). The first three are
good for IO-bound work and the last two are good for CPU-bound work. Ractor support is
experimental and comes with limitations.

Want to see some code? Jump to [the examples](#examples) section. <br>
Want to see a self-hosted LLM environment built on llm.rb? Check out [relay.app](https://github.com/llmrb/relay.app). <br>
Want to use llm.rb with mruby ? Check out [mruby-llm](https://github.com/llmrb/mruby-llm). <br>
Want support ? [Open an issue](https://github.com/llmrb/llm.rb/issues),
join us on [irc.libera.chat/#llm.rb](https://web.libera.chat/)
or [email the maintainer](mailto:0x1eef@hardenedbsd.org).

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

## Standout features

The following list is **not exhaustive**, but it covers a lot of ground.

#### Skills

Skills are reusable, directory-backed capabilities loaded from `SKILL.md`.
They run through the same runtime as tools, agents, and MCP. They do not
require a second orchestration layer or a parallel abstraction. If you've
used Claude or Codex, you know the general idea of skills, and llm.rb
supports that same concept with the same execution model as the rest of the
system.

In llm.rb, a skill has frontmatter and instructions. The frontmatter can
define `name`, `description`, and `tools`. The `tools` entries are tool names,
and each name must resolve to a subclass of
[`LLM::Tool`](https://0x1eef.github.io/x/llm.rb/LLM/Tool.html) that is already
loaded in the runtime.

If you want Claude/Codex-like skills that can drive scripts or shell
commands, you would typically pair the skill with a tool that can execute
system commands.

```yaml
---
name: release
description: Prepare a release
tools:
  - search_docs
  - git
---
Review the release state, summarize what changed, and prepare the release.
```

```ruby
class Agent < LLM::Agent
  model "gpt-5.4-mini"
  skills "./skills/release"
  tracer { LLM::Tracer::Logger.new(llm, path: "logs/release-agent.log") }
end

llm = LLM.openai(key: ENV["KEY"])
Agent.new(llm, stream: $stdout).talk("Let's prepare the release!")
```

#### ORM

Any ActiveRecord model or Sequel model can become an agent-capable model,
including existing business and domain models, without forcing you into a
separate agent table or a second persistence layer.

`acts_as_agent` extends a model with agent capabilities: the same runtime
surface as [`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html),
because it actually wraps an `LLM::Agent`, plus persistence through one text,
JSON, or JSONB-backed `data` column on the same table. If your app also has
provider or model columns, provide them to llm.rb through `set_provider` and
`set_context`.


```ruby
class Ticket < ApplicationRecord
  acts_as_agent provider: :set_provider, context: :set_context
  model "gpt-5.4-mini"
  instructions "You are a support assistant."

  private

  def set_provider
    LLM.openai(key: ENV["OPENAI_SECRET"])
  end

  def set_context
    { mode: :responses, store: false }
  end
end
```

#### Agentic Patterns

llm.rb is especially strong when you want to build agentic systems in a Ruby
way. Agents can be ordinary application models with state, associations,
tools, skills, and persistence, which makes it much easier to build systems
where users have their own specialized agents instead of treating agents as
something outside the app.

That pattern works so well in llm.rb because
[`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html),
`acts_as_agent`, `plugin :agent`, skills, tools, and persisted runtime state
all fit the same execution model. The runtime stays small enough that the
main design work becomes application design, not orchestration glue.

For a concrete example, see
[How to build a platform of agents](https://0x1eef.github.io/posts/how-to-build-a-platform-of-agents).

#### Persistence

The same runtime can be serialized to disk, restored later, persisted in JSON
or JSONB-backed ORM columns, resumed across process boundaries, or shared
across long-lived workflows.

```ruby
ctx = LLM::Context.new(llm)
ctx.talk("Remember that my favorite language is Ruby.")
ctx.save(path: "context.json")
```

#### Context Compaction

Long-lived contexts can compact older history into a summary instead of
growing forever. Compaction is built into [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html)
through [`LLM::Compactor`](https://0x1eef.github.io/x/llm.rb/LLM/Compactor.html),
and when a stream is present it emits `on_compaction` and
`on_compaction_finish` through [`LLM::Stream`](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html).
The compactor can also use a different model from the main context, which is
useful when you want summarization to run on a cheaper or faster model.
`token_threshold:` accepts either a fixed token count or a percentage string
like `"90%"`, which resolves against the active model context window and
triggers compaction once total token usage goes over that percentage.

```ruby
ctx = LLM::Context.new(
  llm,
  compactor: {
    token_threshold: "90%",
    retention_window: 8,
    model: "gpt-5.4-mini"
  }
)
```

#### Guards

Guards let llm.rb supervise agentic execution, not just run it.
They live on [`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html),
can inspect the current runtime state, and can step in when a context is no
longer making progress.

[`LLM::LoopGuard`](https://0x1eef.github.io/x/llm.rb/LLM/LoopGuard.html) is
the built-in implementation. It detects repeated tool-call patterns and
blocks pending tool execution with in-band guarded tool errors instead of
letting the loop keep spinning. [`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html)
enables that guard by default through its wrapped context.

```ruby
ctx = LLM::Context.new(llm)
ctx.guard = MyGuard.new
```

#### Transformers

Transformers let llm.rb rewrite outgoing prompts and params before a request
is sent to the provider. They also live on
[`LLM::Context`](https://0x1eef.github.io/x/llm.rb/LLM/Context.html), but
they solve a different problem from guards: instead of blocking execution,
they can normalize or scrub what gets sent. When a stream is present, that
lifecycle is also exposed through
[`LLM::Stream`](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html) with
`on_transform` and `on_transform_finish`.

That makes them a good fit for things like PII scrubbing, prompt
normalization, or request-level param injection. A transformer just needs to
implement `call(ctx, prompt, params)` and return `[prompt, params]`. That
means a transformer can scrub plain text prompts, but it can also scrub
[`LLM::Function::Return`](https://0x1eef.github.io/x/llm.rb/LLM/Function/Return.html)
values. In other words, you can intercept a tool call's return value and
modify it before sending it back to the LLM.

That is also a useful UI hook. A stream can surface messages like
`Anonymizing your data...` before a scrubber runs and `Data anonymized.`
after it finishes.

```ruby
class ScrubPII
  EMAIL = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i

  def call(ctx, prompt, params)
    [scrub(prompt), params]
  end

  private

  def scrub(prompt)
    case prompt
    when String then prompt.gsub(EMAIL, "[REDACTED_EMAIL]")
    when Array then prompt.map { scrub(_1) }
    when LLM::Function::Return then on_tool_return(prompt)
    else prompt
    end
  end

  def on_tool_return(result)
    value = case result.name
    when "lookup-customer" then scrub_value(result.value)
    else result.value
    end
    LLM::Function::Return.new(result.id, result.name, value)
  end

  def scrub_value(value)
    case value
    when String then value.gsub(EMAIL, "[REDACTED_EMAIL]")
    when Array then value.map { scrub_value(_1) }
    when Hash then value.transform_values { scrub_value(_1) }
    else value
    end
  end
end

ctx = LLM::Context.new(llm)
ctx.transformer = ScrubPII.new
```

When a stream is present, that transformer lifecycle is also exposed through
`on_transform` and `on_transform_finish` on
[`LLM::Stream`](https://0x1eef.github.io/x/llm.rb/LLM/Stream.html).

#### LLM::Stream

`LLM::Stream` is not just for printing tokens. It supports `on_content`,
`on_reasoning_content`, `on_tool_call`, `on_tool_return`, `on_transform`,
`on_transform_finish`, `on_compaction`, and `on_compaction_finish`, which
means visible output, reasoning output, request rewriting, tool execution,
and context compaction can all be driven through the same execution path.

```ruby
class Stream < LLM::Stream
  def on_tool_call(tool, error)
    queue << (error || ctx.spawn(tool, :thread))
  end

  def on_tool_return(tool, result)
    puts(result.value)
  end
end
```

#### Concurrency

Tool execution can run sequentially with `:call` or concurrently through
`:thread`, `:task`, `:fiber`, `:fork`, and experimental `:ractor`, without
rewriting your tool layer. Async tasks, threads, and fibers are the
I/O-bound options. Fork and ractor are the CPU-bound options. `:fork`
requires [`xchan.rb`](https://github.com/0x1eef/xchan.rb#readme) support,
and `:ractor` is still experimental.

`:fiber` uses `Fiber.schedule`, so it requires `Fiber.scheduler`.

```ruby
class Agent < LLM::Agent
  model "gpt-5.4-mini"
  tools FetchWeather, FetchNews, FetchStock
  concurrency :thread
end
```

#### MCP

Remote MCP tools and prompts are not bolted on as a separate integration
stack. They adapt into the same tool and prompt path used by local tools,
skills, contexts, and agents.

Use `mcp.run do ... end` for scoped work where the client should start and
stop around one block. Use `mcp.start` and `mcp.stop` directly when you need
finer sequential control across several steps before shutting the client down.

```ruby
mcp = LLM::MCP.http(
  url: "https://api.githubcopilot.com/mcp/",
  headers: {"Authorization" => "Bearer #{ENV["GITHUB_PAT"]}"},
  persistent: true
)
mcp.run do
  ctx = LLM::Context.new(llm, tools: mcp.tools)
end
```

#### Cancellation

Cancellation is one of the harder problems to get right, and while llm.rb
makes it possible, it still requires careful engineering to use effectively.
The point though is that it is possible to stop in-flight provider work cleanly
through the same runtime, and the model used by llm.rb is directly inspired by
Go's context package. In fact, llm.rb is heavily inspired by Go but with a Ruby
twist.

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
  `:fork`, or experimental `:ractor` support for class-based tools. MCP tools
  are not supported by the current `:ractor` mode, but mixed tool sets can
  still route MCP tools and local tools through different strategies at
  runtime. By default, the tool attempt budget is `25`. When an agent
  exhausts that budget, it sends advisory tool errors back through the model
  instead of raising out of the runtime. Set `tool_attempts: nil` to disable
  that advisory behavior.
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
  Use async tasks, threads, fibers, forks, or experimental ractors without
  rewriting your tool layer. Async tasks, threads, and fibers are the
  I/O-bound options. Fork and ractor are the CPU-bound options. `:fork`
  requires [`xchan.rb`](https://github.com/0x1eef/xchan.rb#readme) support.
  The current `:ractor` mode is for class-based tools, and MCP tools are
  not supported by ractor, but mixed workloads can branch on `tool.mcp?`
  and choose a supported strategy per tool. Class-based `:ractor` tools
  still emit normal tool tracer callbacks. `:fiber` uses `Fiber.schedule`,
  so it requires `Fiber.scheduler`.
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
  Z.ai, xAI, AWS Bedrock, llama.cpp, and Ollama through the same runtime.
- **Tools are explicit** <br>
  Run local tools, provider-native tools, and MCP tools through the same path
  with fewer special cases.
- **Skills become bounded runtime capabilities** <br>
  Point llm.rb at directories with a `SKILL.md`, resolve named tools through
  the registry, and adapt each skill into its own callable capability through
  the normal runtime. Unlike a generic skill-discovery tool, each skill runs
  with its own bounded tool subset and behaves like a task-scoped sub-agent.
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

Execution:
- **Chat & Contexts** — stateless and stateful interactions with persistence
- **Context Serialization** — save and restore state across processes or time
- **Streaming** — visible output, reasoning output, tool-call events
- **Request Interruption** — stop in-flight provider work cleanly
- **Concurrent Execution** — threads, async tasks, and fibers

Runtime Building Blocks:
- **Tool Calling** — class-based tools and closure-based functions
- **Run Tools While Streaming** — overlap model output with tool latency
- **Agents** — reusable assistants with tool auto-execution
- **Skills** — directory-backed capabilities loaded from `SKILL.md`
- **MCP Support** — stdio and HTTP MCP clients with prompt and tool support
- **Context Compaction** — summarize older history in long-lived contexts

Data and Structure:
- **Structured Outputs** — JSON Schema-based responses
- **Responses API** — stateful response workflows where providers support them
- **Multimodal Inputs** — text, images, audio, documents, URLs
- **Audio** — speech generation, transcription, translation
- **Images** — generation and editing
- **Files API** — upload and reference files in prompts
- **Embeddings** — vector generation for search and RAG
- **Vector Stores** — retrieval workflows

Operations:
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

This example uses [`LLM::Agent`](https://0x1eef.github.io/x/llm.rb/LLM/Agent.html) with directory-backed skills so `SKILL.md` capabilities run through the normal tool path. In llm.rb, a skill is exposed as a tool in the runtime. When that tool is called, it spawns a sub-agent with relevant context plus the instructions and tool subset declared in its own `SKILL.md`. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

Each skill runs only with the tools declared in its own frontmatter.

```ruby
require "llm"

class Agent < LLM::Agent
  model "gpt-5.4-mini"
  instructions "You are a concise release assistant."
  skills "./skills/release", "./skills/review"
  tracer { LLM::Tracer::Logger.new(llm, path: "logs/release-agent.log") }
end

llm = LLM.openai(key: ENV["KEY"])
puts Agent.new(llm).talk("Use the review skill.").content
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
    queue << ctx.spawn(tool, :thread)
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
stream = Stream.new
ctx = LLM::Context.new(llm, stream:, tools: [System])

ctx.talk("Run `date` and `uname -a`.")
ctx.talk(ctx.wait(:thread)) while ctx.functions.any?
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
token usage goes over that percentage. <br> See the [deepdive (web)](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) or [deepdive (markdown)](resources/deepdive.md) for more examples.

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
ctx.talk(ctx.call(:functions)) while ctx.functions.any?
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
  ctx.talk(ctx.call(:functions)) while ctx.functions.any?
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
