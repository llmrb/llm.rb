<p align="center">
  <a href="llm.rb"><img src="https://github.com/llmrb/llm.rb/raw/main/llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://0x1eef.github.io/x/llm.rb?rebuild=1"><img src="https://img.shields.io/badge/docs-0x1eef.github.io-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-4.14.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is a runtime for building AI systems that integrate directly with your
application. It is not just an API wrapper. It provides a unified execution
model for providers, tools, MCP servers, streaming, schemas, files, and
state.

It is built for engineers who want control over how these systems run. llm.rb
stays close to Ruby, runs on the standard library by default, loads optional
pieces only when needed, and remains easy to extend. It also works well in
Rails or ActiveRecord applications, and it includes built-in Sequel plugin
support, where a small wrapper around context persistence is enough to save
and restore long-lived conversation state across requests, jobs, or retries.

Most LLM libraries stop at request/response APIs. Building real systems means
stitching together streaming, tools, state, persistence, and external
services by hand. llm.rb provides a single execution model for all of these,
so they compose naturally instead of becoming separate subsystems.

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
  Use threads, fibers, or async tasks without rewriting your tool layer.
- **Advanced workloads are built in, not bolted on** <br>
  Streaming, concurrent tool execution, persistence, tracing, and MCP support
  all fit the same runtime model.

### Integration

- **MCP is built in** <br>
  Connect to MCP servers over stdio or HTTP without bolting on a separate
  integration stack.
- **Sequel persistence is built in** <br>
  Use `plugin :llm` to persist `LLM::Context` state on a Sequel model with
  sensible default columns, then pass provider setup through
  `provider:` when you need it. Use `format: :string` for text columns or
  `format: :jsonb` when you want native PostgreSQL JSON storage.
- **Persistent HTTP pooling is shared process-wide** <br>
  When enabled, separate
  [`LLM::Provider`](https://0x1eef.github.io/x/llm.rb/LLM/Provider.html)
  instances with the same endpoint settings can share one persistent
  pool, and separate HTTP
  [`LLM::MCP`](https://0x1eef.github.io/x/llm.rb/LLM/MCP.html)
  instances can do the same, instead of each object creating its own
  isolated per-instance transport.
- **Provider support is broad** <br>
  Work with OpenAI, OpenAI-compatible endpoints, Anthropic, Google, DeepSeek,
  Z.ai, xAI, llama.cpp, and Ollama through the same runtime.
- **Tools are explicit** <br>
  Run local tools, provider-native tools, and MCP tools through the same path
  with fewer special cases.
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

**REPL**

See the [deepdive](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) for more examples.

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

**Sequel (ORM)**

See the [deepdive](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) for more examples.

```ruby
require "llm"
require "sequel"
require "sequel/plugins/llm"

class Context < Sequel::Model
  plugin :llm, provider: -> { {key: ENV["#{provider.upcase}_SECRET"], persistent: true } }
end

ctx = Context.create(provider: "openai", model: "gpt-5.4-mini")
ctx.talk("Remember that my favorite language is Ruby")
puts ctx.talk("What is my favorite language?").content
```

## Resources

- [deepdive](https://0x1eef.github.io/x/llm.rb/file.deepdive.html) is the
  examples guide.
- [_examples/relay](./_examples/relay) shows a real application built on top
  of llm.rb.
- [doc site](https://0x1eef.github.io/x/llm.rb?rebuild=1) has the API docs.

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)
