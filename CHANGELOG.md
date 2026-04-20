# Changelog

## Unreleased

Changes since `v4.20.2`.

### Change

* **Add `plugin :agent` for Sequel models** <br>
  Add Sequel support for `plugin :agent`, similar to ActiveRecord's
  `acts_as_agent`, so models can wrap `LLM::Agent` with built-in
  persistence.

* **Load directory-backed skills through `LLM::Context` and `LLM::Agent`** <br>
  Add `skills:` to `LLM::Context` and `skills ...` to `LLM::Agent` so
  directories with `SKILL.md` can be loaded, resolved into tools, and run
  through the normal llm.rb tool path.

## v4.20.2

Changes since `v4.20.1`.

This patch release improves runtime behavior around interruption and mixed
concurrency waits. It also rounds out response API uniformity for Google
completion responses.

### Fix

* **Expose Google completion response IDs through `.id`** <br>
  Add `LLM::Response#id` support to Google completion responses so tracer
  and caller code can rely on the same API used by other providers.

* **Track interrupt ownership on the active request** <br>
  Bind `LLM::Context` interruption to the fiber running `talk` or `respond`
  so `interrupt!` works correctly when requests are started outside the
  context's initialization fiber.

### Change

* **Allow mixed concurrency strategies in `wait(...)`** <br>
  Let `LLM::Context#wait`, `LLM::Stream#wait`, and `LLM::Agent.concurrency`
  accept arrays such as `[:thread, :ractor]` so mixed tool sets can wait on
  more than one concurrency strategy.

## v4.20.1

Changes since `v4.20.0`.

This patch release fixes ORM option resolution in the Sequel and
ActiveRecord wrappers. Symbol-based `provider:` and `context:` hooks now
resolve correctly, and internal default option constants are referenced
explicitly instead of relying on nested constant lookup.

### Fix

* **Fix symbol-based ORM option hooks for provider and context hashes** <br>
  Make `provider:` and `context:` resolve symbol hooks through the model in
  the Sequel plugin and ActiveRecord wrappers instead of falling back to an
  empty hash.

* **Fix ORM wrapper constant lookup for option defaults** <br>
  Qualify internal `EMPTY_HASH` / `DEFAULTS` references in the Sequel plugin
  and ActiveRecord wrappers so option resolution does not depend on nested
  constant lookup quirks.

## v4.20.0

Changes since `v4.19.0`.

This release adds better support for tagged prompt content. `LLM::Context`
can now serialize and restore `image_url`, `local_file`, and `remote_file`
content cleanly, and `LLM::Message` now exposes helpers for inspecting
tagged image and file attachments.

### Change

* **Round-trip tagged prompt objects through `LLM::Context`** <br>
  Teach `LLM::Context` serialization and restore to preserve
  `image_url`, `local_file`, and `remote_file` content across
  `to_json` / `restore`.

* **Add attachment helpers to `LLM::Message`** <br>
  Add `image_url?`, `image_urls`, `file?`, and `files` so callers can
  inspect messages for tagged image and file content more directly.

## v4.19.0

Changes since `v4.18.0`.

This release tightens the ActiveRecord and ORM integration layer. It adds
inline agent DSL blocks to `acts_as_agent` so agent defaults can be defined
where the wrapper is declared, and it exposes the resolved provider through
public `llm` methods on the ActiveRecord and Sequel wrappers.

### Change

* **Make ORM provider access public through `llm`** <br>
  Expose the resolved provider on the Sequel plugin and the ActiveRecord
  `acts_as_llm` / `acts_as_agent` wrappers through a public `llm` method.

* **Allow inline agent DSL blocks in `acts_as_agent`** <br>
  Let ActiveRecord models configure `model`, `tools`, `schema`,
  `instructions`, and `concurrency` directly inside the `acts_as_agent`
  declaration block.

## v4.18.0

Changes since `v4.17.0`.

This release improves tracing and tool execution behavior across llm.rb.
It makes provider tracers default to the provider instance, adds
`LLM::Provider#with_tracer` for scoped overrides, restores tool tracing for
concurrent and streamed tool execution, extends streamed tracing to MCP tools,
and adds symbol-based ORM option hooks alongside experimental ractor tool
concurrency.

### Change

* **Make provider tracers default to the provider instance** <br>
  Change `llm.tracer = ...` so it sets a provider default tracer instead of
  relying on scoped fiber-local state alone. This makes tracer configuration
  behave more predictably across normal tasks, threads, and fibers that share
  the same provider instance.

* **Add `LLM::Provider#with_tracer` for scoped overrides** <br>
  Add `with_tracer` as the opt-in escape hatch for request- or turn-scoped
  tracer overrides. Use it when you want temporary tracing on the current
  fiber without replacing the provider's default tracer.

* **Trace concurrent tool calls outside ractors** <br>
  Make tool tracing fire correctly when functions run through `:thread`,
  `:task`, or `:fiber` concurrency. Experimental `:ractor` execution still
  does not emit tool tracer events.

* **Trace streamed tool calls, including MCP tools** <br>
  Bind stream metadata through `LLM::Stream#extra` so streamed tool calls
  inherit tracer and model context before they are handed to `on_tool_call`.
  This restores tool tracing for streamed MCP and local tool execution.

* **Support symbol-based ORM option hooks** <br>
  Let `provider:`, `context:`, and `tracer:` on the Sequel plugin and
  the ActiveRecord `acts_as_llm` / `acts_as_agent` wrappers resolve through
  model method names as well as procs.

* **Add experimental ractor tool concurrency** <br>
  Add `:ractor` support to `LLM::Function#spawn`, `LLM::Function::Array#wait`,
  `LLM::Stream#wait`, and `LLM::Agent.concurrency` so class-based tools with
  ractor-safe arguments and return values can run in Ruby ractors and report
  their results back into the normal LLM tool-return path. MCP tools are not
  supported by the current `:ractor` mode, but mixed workloads can still
  branch on `tool.mcp?` and choose a supported strategy per tool. `:ractor`
  is especially useful for CPU-bound tools, while `:task`, `:fiber`, or
  `:thread` may be a better fit for I/O-bound work.

## v4.17.0

Changes since `v4.16.1`.

This release expands agent support across llm.rb. It brings `LLM::Agent`
closer to `LLM::Context`, adds configurable automatic tool concurrency
including experimental ractor support for class-based tools,
extends persisted ORM wrappers with more of the context runtime surface and
tracer hooks, and introduces built-in ActiveRecord agent persistence through
`acts_as_agent`.

### Change

* **Add configurable tool concurrency to `LLM::Agent`** <br>
  Add the class-level `concurrency` DSL to `LLM::Agent` so automatic
  tool loops can run with `:call`, `:thread`, `:task`, `:fiber`, or
  experimental `:ractor` support for class-based tools instead of
  always executing sequentially.

* **Bring `LLM::Agent` closer to `LLM::Context`** <br>
  Expand `LLM::Agent` so it exposes more of the same runtime surface as
  `LLM::Context`, including returns, interruption, mode, cost, context
  window, structured serialization, and other context-backed helpers,
  while still auto-managing tool loops.

* **Refresh agent docs and coverage** <br>
  Update the README and deep dive to explain the current role of
  `LLM::Agent`, add examples that show automatic tool execution and
  concurrency, and add focused specs for the expanded agent surface and
  tool-loop behavior.

* **Add ORM tracer hooks for persisted contexts** <br>
  Add `tracer:` to both the Sequel plugin and `acts_as_llm` so models
  can resolve and assign tracers onto the provider used by their persisted
  `LLM::Context`.

* **Bring persisted ORM wrappers closer to `LLM::Context`** <br>
  Expand both the Sequel plugin and `acts_as_llm` so record-backed
  contexts expose more of the same runtime surface as `LLM::Context`,
  including mode, returns, interruption, prompt helpers, file helpers,
  and tracer access.

* **Add ActiveRecord agent persistence with `acts_as_agent`** <br>
  Add `acts_as_agent` for ActiveRecord models that should wrap
  `LLM::Agent`, reusing the same record-backed runtime shape as
  `acts_as_llm` while letting tool execution be managed by the agent.

## v4.16.1

Changes since `v4.16.0`.

This release tightens ORM persistence by removing an unnecessary JSON
round-trip when restoring structured `:json` and `:jsonb` context
payloads.

### Change

* **Restore structured ORM payloads directly** <br>
  Teach `LLM::Context#restore` to accept parsed data payloads and use
  that path from the ActiveRecord and Sequel persistence wrappers for
  `format: :json` and `:jsonb`, avoiding a redundant
  `Hash -> JSON string -> Hash` round-trip on restore.

## v4.16.0

Changes since `v4.15.0`.

This release expands ORM support with built-in ActiveRecord persistence
and improves compatibility with OpenAI-compatible gateways, proxies, and
self-hosted servers that use non-standard API root paths.

### Change

* **Support OpenAI-compatible base paths** <br>
  Add `base_path:` to provider configuration so OpenAI-compatible
  endpoints can vary both host and API prefix. This supports providers,
  proxies, and gateways that keep OpenAI request shapes but use
  non-standard URL layouts such as DeepInfra's `/v1/openai/...`.

* **Add ActiveRecord context persistence with `acts_as_llm`** <br>
  Add a built-in ActiveRecord wrapper that mirrors the Sequel plugin
  API so applications can persist `LLM::Context` state on records with
  default columns, provider/context hooks, validation-backed writes,
  and `format: :string`, `:json`, or `:jsonb` storage.

## v4.15.0

Changes since `v4.14.0`.

### Change

* **Reduce OpenAI stream parser merge overhead** <br>
  Special-case the most common single-field deltas, streamline
  incremental tool-call merging, and avoid repeated JSON parse attempts
  until streamed tool arguments look complete.

* **Cache streaming callback capabilities in parsers** <br>
  Cache callback support checks once at parser initialization time in
  the OpenAI, OpenAI Responses, Anthropic, Google, and Ollama stream
  parsers instead of repeating `respond_to?` checks on hot streaming
  paths.

* **Reduce OpenAI Responses parser lookup overhead** <br>
  Special-case the hot Responses API event paths and cache the current
  output item and content part so streamed output text deltas do less
  repeated nested lookup work.

* **Add a Sequel context persistence plugin** <br>
  Add `plugin :llm` for Sequel models so apps can persist
  `LLM::Context` state with default columns and pass provider setup
  through `provider:` when needed. The plugin now also supports
  `format: :string`, `:json`, or `:jsonb` for text and native JSON
  storage when Sequel JSON typecasting is enabled.

* **Improve streaming parser performance** <br>
  In the local replay-based `stream_parser` benchmark versus
  `v4.14.0` (median of 20 samples, 5000 iterations), plain Ruby is a
  small overall win: the generic eventstream path is about 0.4%
  faster, the OpenAI stream parser is about 0.5% faster, and the
  OpenAI Responses parser is about 1.6% faster, with unchanged
  allocations. Under YJIT on the same benchmark, the generic
  eventstream path is about 0.9% faster and the OpenAI stream parser
  is about 0.4% faster, while the OpenAI Responses parser is about
  0.7% slower, also with unchanged allocations.

  Compared to `v4.13.0`, the larger `v4.14.0` streaming gains still
  hold. The generic eventstream path remains dramatically faster than
  `v4.13.0`, the OpenAI stream parser remains modestly faster, and the
  OpenAI Responses parser is roughly flat to slightly better depending
  on runtime. In other words, current keeps the large eventstream win
  from `v4.14.0`, adds only small incremental changes beyond that, and
  does not turn the post-`v4.14.0` parser work into another large
  benchmark jump.

## v4.14.0

Changes since `v4.13.0`.

This release adds request interruption for contexts, reworks provider
HTTP internals for lower-overhead streaming, and fixes MCP clients so
parallel tool calls can safely share one connection.

### Add

* **Add request interruption support** <br>
  Add `LLM::Context#interrupt!`, `LLM::Context#cancel!`, and
  `LLM::Interrupt` for interrupting in-flight provider requests,
  inspired by Go's context cancellation.

### Change

* **Rework provider HTTP transport internals** <br>
  Rework provider HTTP around `LLM::Provider::Transport::HTTP` with
  explicit transient and persistent transport handling.

* **Reduce SSE parser overhead** <br>
  Dispatch raw parsed values to registered visitors instead of building
  an `Event` object for every streamed line.

* **Reduce provider streaming allocations** <br>
  Decode streamed provider payloads directly in
  `LLM::Provider::Transport::HTTP` before handing them to provider
  parsers, which cuts allocation churn and gives a smaller streaming
  speed bump.

* **Reduce generic SSE parser allocations** <br>
  Keep unread event-stream buffer data in place until compaction is
  worthwhile, which lowers allocation churn in the remaining generic
  SSE path.

* **Improve streaming parser performance** <br>
  In the local replay-based `stream_parser` benchmark versus `v4.13.0`
  (median of 20 samples, 5000 iterations):
  Plain Ruby: the generic eventstream path is about 53% faster with
  about 32% fewer allocations, the OpenAI stream parser is about 11%
  faster with about 4% fewer allocations, and the OpenAI Responses
  parser is about 3% faster with unchanged allocations.
  YJIT on the current parser benchmark harness: the current tree is
  about 26% faster than non-YJIT on the generic eventstream path,
  about 18% faster on the OpenAI stream parser, and about 16% faster
  on the OpenAI Responses parser, with allocations unchanged.

### Fix

* **Support parallel MCP tool calls on one client** <br>
  Route MCP responses by JSON-RPC id so concurrent tool calls can
  share one client and transport without mismatching replies.

* **Use explicit MCP non-blocking read errors** <br>
  Use `IO::EAGAINWaitReadable` while continuing to retry on
  `IO::WaitReadable`.

## v4.13.0

Changes since `v4.12.0`.

This release expands MCP prompt support, improves reasoning support in the
OpenAI Responses API, and refreshes the docs around llm.rb's runtime model,
contexts, and advanced workflows.

### Add

- Add `LLM::MCP#prompts` and `LLM::MCP#find_prompt` for MCP prompt support.

### Change

- Rework the README around llm.rb as a runtime for AI systems.
- Add a dedicated deep dive guide for providers, contexts, persistence,
  tools, agents, MCP, tracing, multimodal prompts, and retrieval.

### Fix

All of these fixes apply to MCP:

- fix(mcp): raise `LLM::MCP::MismatchError` on mismatched response ids.
- fix(mcp): normalize prompt message content while preserving the original payload.

All of these fixes apply to OpenAI's Responses API:

- fix(openai): emit `on_reasoning_content` for streamed reasoning summaries.
- fix(openai): skip `previous_response_id` on `store: false` follow-up calls.
- fix(openai): fall back to an empty object schema for tools without params.
- fix(openai): preserve original tool-call payloads on re-sent assistant tool messages.
- fix(openai): emit `output_text` for assistant-authored response content.
- fix(openai): return `nil` for `system_fingerprint` on normalized response objects.

## v4.12.0

Changes since `v4.11.1`.

This release expands advanced streaming and MCP execution while reframing
llm.rb more clearly as a system integration layer for LLMs, tools, MCP
sources, and application APIs.

### Add

- Add `persistent` as an alias for `persist!` on providers and MCP transports.
- Add `LLM::Stream#on_tool_return` for observing completed streamed tool work.
- Add `LLM::Function::Return#error?`.

### Change

- Expect advanced streaming callbacks to use `LLM::Stream` subclasses
  instead of duck-typing them onto arbitrary objects. Basic `#<<`
  streaming remains supported.

### Fix

- Fix Anthropic tools without params by always emitting `input_schema`.
- Fix Anthropic tool-only responses to still produce an assistant message.
- Fix Anthropic tool results to use the `user` role.
- Fix Anthropic tool input normalization.

## v4.11.1

Changes since `v4.11.0`.

### Fix

* Cast OpenTelemetry tool-related values to strings. <br>
  Otherwise they're rejected by opentelemetry-sdk as invalid attributes.

## v4.11.0

Changes since `v4.10.0`.

### Add

- Add `LLM::Stream` for richer streaming callbacks, including `on_content`,
  `on_reasoning_content`, and `on_tool_call` for concurrent tool execution.
- Add `LLM::Stream#wait` as a shortcut for `queue.wait`.
- Add `LLM::Context#wait` as a shortcut for the configured stream's `wait`.
- Add `LLM::Context#call(:functions)` as a shortcut for `functions.call`.
- Add `LLM::Function.registry` and enhanced support for MCP tools in
  `LLM::Tool.registry` for tool resolution during streaming.
- Add normalized `LLM::Response` for OpenAI Responses, providing `content`,
  `content!`, `messages` / `choices`, `usage`, and `reasoning_content`.
- Add `mode: :responses` to `LLM::Context` for routing `talk` through the
  Responses API.
- Add `LLM::Context#returns` for collecting pending tool returns from the context.
- Add persistent HTTP connection pooling for repeated MCP tool calls via
  `LLM.mcp(http: ...).persist!`.
- Add explicit MCP transport constructors via `LLM::MCP.stdio(...)` and
  `LLM::MCP.http(...)`.

### Fix

- Fix Google tool-call handling by synthesizing stable ids when Gemini does
  not provide a direct tool-call id.

## v4.10.0

Changes since `v4.9.0`.

### Add

- Add HTTP transport for MCP with `LLM::MCP::Transport::HTTP` for remote servers
- Add JSON Schema union types (`any_of`, `all_of`, `one_of`) with parser integration
- Add JSON Schema type array union support (e.g., `"type": ["object", "null"]`)
- Add JSON Schema type inference from `const`, `enum`, or `default` fields

### Change

- Update `LLM::MCP` constructor for exclusive `http:` or `stdio:` transport
- Update `LLM::MCP` documentation for HTTP transport support

## v4.9.0

Changes since `v4.8.0`.

### Add

- Add fiber-based concurrency with `LLM::Function::FiberGroup` and
  `LLM::Function::TaskGroup` classes for lightweight async execution.
- Add `:thread`, `:task`, and `:fiber` strategy parameter to
  `LLM::Function#spawn` for explicit concurrency control.
- Add stdio MCP client support, including remote tool discovery and
  invocation through `LLM.mcp`, `LLM::Context`, and existing function/tool
  APIs.
- Add model registry support via `LLM::Registry`, including model
  metadata lookup, pricing, modalities, limits, and cost estimation.
- Add context access to a model context window via
  `LLM::Context#context_window`.
- Add tracking of defined tools in the tool registry.
- Add `LLM::Schema::Enum`, enabling `Enum[...]` as a schema/tool
  parameter type.
- Add top-level Anthropic system instruction support using Anthropic's
  provider-specific request format.
- Add richer tracing hooks and extra metadata support for
  LangSmith/OpenTelemetry-style traces.
- Add rack/websocket and Relay-related example work, including MCP-focused
  examples.
- Add concurrent tool execution with `LLM::Function#spawn`,
  `LLM::Function::Array` (`call`, `wait`, `spawn`), and
  `LLM::Function::ThreadGroup`.
- Add `LLM::Function::ThreadGroup#alive?` method for non-blocking
  monitoring of concurrent tool execution.
- Add `LLM::Function::ThreadGroup#value` alias for `ThreadGroup#wait` for
  consistency with Ruby's `Thread#value`.

### Change

- Rename `LLM::Session` to `LLM::Context` throughout the codebase to better
  reflect the concept of a stateful interaction environment.
- Rename `LLM::Gemini` to `LLM::Google` to better reflect provider naming.
- Standardize model objects across providers around a smaller common
  interface.
- Switch registry cost internals from `LLM::Estimate` to `LLM::Cost`.
- Update image generation defaults so OpenAI and xAI consistently return
  base64-encoded image data by default.
- Update `LLM::Bot` deprecation warning from v5.0 to v6.0, giving users
  more time to migrate to `LLM::Context`.
- Rework the README and screencast documentation to better cover MCP,
  registry, contexts, prompts, concurrency, providers, and example flow.
- Expand the README with architecture, production, and provider guidance
  while improving readability and example ordering.

### Fix

- Fix local schema `$ref` resolution in `LLM::Schema::Parser`.
- Fix multiple MCP issues around stdio env handling, request IDs, registry
  interaction, tool registration, and filtering of MCP tools from the
  standard tool registry.
- Fix stream parsing issues, including chunk-splitting bugs and safer
  handling of streamed error responses.
- Fix prompt handling across contexts, agents, and provider adapters so
  prompt turns remain consistent in history and completions.
- Fix several tool/context issues, including function return wrapping,
  tool lookup after deserialization, unnamed subclass filtering, and
  thread-safety around tool registry mutations.
- Fix Google tool-call handling to preserve `thoughtSignature`.
- Fix `LLM::Tracer::Logger` argument handling.
- Fix packaging/docs issues such as registry files in the gemspec and
  stale provider docs.
- Fix Google provider handling of `nil` function IDs during context
  deserialization.
- Fix MCP stdio transport by increasing poll timeout for better
  reliability.
- Fix Google provider to properly cast non-Hash tool results into Hash
  format for API compatibility.
- Fix schema parser to support recursive normalization of `Array`,
  `LLM::Object`, and nested structures.
- Fix DeepSeek provider to tolerate malformed tool arguments.
- Fix `LLM::Function::TaskGroup#alive?` to properly delegate to
  `Async::Task#alive?`.
- Fix various RuboCop errors across the codebase.
- Fix DeepSeek provider to handle JSON that might be valid but unexpected.

### Notes

Notable merged work in this range includes:

- `feat(function): add fiber-based concurrency for async environments (#64)`
- `feat(mcp): add stdio MCP support (#134)`
- `Add LLM::Registry + cost support (#133)`
- `Consistent model objects across providers (#131)`
- `Add rack + websocket example (#130)`
- `feat(gemspec): add changelog URI (#136)`
- `feat(function): alias ThreadGroup#wait as ThreadGroup#value (#62)`
- README and screencast refresh across `#66`, `#67`, `#68`, `#71`, and
  `#72`
- `chore(bot): update deprecation warning from v5.0 to v6.0`
- `fix(deepseek): tolerate malformed tool arguments`
- `refactor(context): Rename Session as Context (#70)`

Comparison base:
- Latest tag: `v4.8.0` (`6468f2426ee125823b7ae43b4af507b125f96ffc`)
- HEAD used for this changelog: `915c48da6fda9bef1554ff613947a6ce26d382e3`
