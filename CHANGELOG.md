# Changelog

## Unreleased

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
  storage.

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
