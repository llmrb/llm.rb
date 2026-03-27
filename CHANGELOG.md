# Changelog

## Unreleased

Changes since `v4.8.0`.

### Add

- Add stdio MCP client support, including remote tool discovery and invocation through `LLM.mcp`, `LLM::Session`, and existing function/tool APIs.
- Add model registry support via `LLM::Registry`, including model metadata lookup, pricing, modalities, limits, and cost estimation.
- Add session access to a model context window via `LLM::Session#context_window`.
- Add tracking of defined tools in the tool registry.
- Add `LLM::Schema::Enum`, enabling `Enum[...]` as a schema/tool parameter type.
- Add top-level Anthropic system instruction support using Anthropic's provider-specific request format.
- Add richer tracing hooks and extra metadata support for LangSmith/OpenTelemetry-style traces.
- Add rack/websocket and Relay-related example work, including MCP-focused examples.

### Change

- Rename `LLM::Gemini` to `LLM::Google` to better reflect provider naming.
- Standardize model objects across providers around a smaller common interface.
- Switch registry cost internals from `LLM::Estimate` to `LLM::Cost`.
- Update image generation defaults so OpenAI and xAI consistently return base64-encoded image data by default.
- Expand README and screencast documentation for MCP, registry, context windows, enums, prompts, and concurrency.

### Fix

- Fix local schema `$ref` resolution in `LLM::Schema::Parser`.
- Fix multiple MCP issues around stdio env handling, request IDs, registry interaction, tool registration, and filtering of MCP tools from the standard tool registry.
- Fix stream parsing issues, including chunk-splitting bugs and safer handling of streamed error responses.
- Fix prompt handling across sessions, agents, and provider adapters so prompt turns remain consistent in history and completions.
- Fix several tool/session issues, including function return wrapping, tool lookup after deserialization, unnamed subclass filtering, and thread-safety around tool registry mutations.
- Fix Google tool-call handling to preserve `thoughtSignature`.
- Fix `LLM::Tracer::Logger` argument handling.
- Fix packaging/docs issues such as registry files in the gemspec and stale provider docs.
- Fix Google provider handling of `nil` function IDs during session deserialization.
- Fix MCP stdio transport by increasing poll timeout for better reliability.
- Fix Google provider to properly cast non-Hash tool results into Hash format for API compatibility.
- Fix schema parser to support recursive normalization of `Array`, `LLM::Object`, and nested structures.

### Notes

Notable merged work in this range includes:

- `feat(mcp): add stdio MCP support (#134)`
- `Add LLM::Registry + cost support (#133)`
- `Consistent model objects across providers (#131)`
- `Add rack + websocket example (#130)`
- `feat(gemspec): add changelog URI (#136)`

Comparison base:
- Latest tag: `v4.8.0` (`6468f2426ee125823b7ae43b4af507b125f96ffc`)
- HEAD used for this changelog: `612ce8fc40cae4050d9beb3948d37f5b90d95a1b`
