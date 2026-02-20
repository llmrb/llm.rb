<p align="center">
  <a href="llm.rb"><img src="llm.png" width="200" height="200" border="0" alt="llm.rb"></a>
</p>
<p align="center">
  <a href="https://rubydoc.info/github/llmrb/llm.rb"><img src="https://img.shields.io/badge/docs-rubydoc.info-blue.svg" alt="RubyDoc"></a>
  <a href="https://opensource.org/license/0bsd"><img src="https://img.shields.io/badge/License-0BSD-orange.svg?" alt="License"></a>
  <a href="https://github.com/llmrb/llm.rb/tags"><img src="https://img.shields.io/badge/version-4.1.0-green.svg?" alt="Version"></a>
</p>

## About

llm.rb is a zero-dependency Ruby toolkit for Large Language Models that
includes OpenAI, Gemini, Anthropic, xAI (Grok), zAI, DeepSeek, Ollama,
and LlamaCpp. The toolkit includes full support for chat, streaming,
tool calling, audio, images, files, and structured outputs.

## Quick start

#### REPL

The [LLM::Bot](https://rubydoc.info/github/llmrb/llm.rb/LLM/Bot.html) class provides
a session with an LLM provider that maintains conversation history and context across
multiple requests. The following example implements a simple REPL loop:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm, stream: $stdout)
loop do
  print "> "
  bot.chat(STDIN.gets)
  puts
end
```

#### Schema

The [LLM::Schema](https://rubydoc.info/github/llmrb/llm.rb/LLM/Schema.html) class provides
a simple DSL for describing the structure of a response that an LLM emits according
to a JSON schema. The schema lets a client describe what JSON object an LLM should
emit, and the LLM will abide by the schema to the best of its ability:

```ruby
#!/usr/bin/env ruby
require "llm"
require "pp"

class Report < LLM::Schema
  property :category, String, "Report category", required: true
  property :summary, String, "Short summary", required: true
  property :impact, String, "Impact", required: true
  property :timestamp, String, "When it happened", optional: true
end

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm, schema: Report)
res = bot.chat("Structure this report: 'Database latency spiked at 10:42 UTC, causing 5% request timeouts for 12 minutes.'")
pp res.messages.first(&:assistant?).content!
```

#### Tools

The [LLM::Tool](https://rubydoc.info/github/llmrb/llm.rb/LLM/Tool.html) class lets you
define callable tools for the model. Each tool is described to the LLM as a function
it can invoke to fetch information or perform an action. The model decides when to
call tools based on the conversation; when it does, llm.rb runs the tool and sends
the result back on the next request. The following example implements a simple tool
that runs shell commands:

```ruby
#!/usr/bin/env ruby
require "llm"

class System < LLM::Tool
  name "system"
  description "Run a shell command"
  param :command, String, "Command to execute", required: true

  def call(command:)
    {success: system(command)}
  end
end

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm, tools: [System])
bot.chat("Run `date`.")
bot.chat(bot.functions.map(&:call)) # report return value to the LLM
```

#### Agents

The [LLM::Agent](https://rubydoc.info/github/llmrb/llm.rb/LLM/Agent.html)
class provides a class-level DSL for defining reusable, preconfigured
assistants with defaults for model, tools, schema, and instructions.
Instructions are injected only on the first request, and unlike
[LLM::Bot](https://rubydoc.info/github/llmrb/llm.rb/LLM/Bot.html),
an [LLM::Agent](https://rubydoc.info/github/llmrb/llm.rb/LLM/Agent.html)
will automatically call tools when needed:

```ruby
#!/usr/bin/env ruby
require "llm"

class SystemAdmin < LLM::Agent
  model "gpt-4.1"
  instructions "You are a Linux system admin"
  tools Shell
  schema Result
end

llm = LLM.openai(key: ENV["KEY"])
agent = SystemAdmin.new(llm)
res = agent.chat("Run 'date'")
```

#### Prompts

The [LLM::Bot#build_prompt](https://rubydoc.info/github/llmrb/llm.rb/LLM/Bot.html#build_prompt-instance_method)
method provides a simple DSL for building a chain of messages that
can be sent in a single request. A conversation with an LLM consists
of messages that have a role (eg system, user), and content:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm)
prompt = bot.build_prompt do
  it.system "Be concise and show your reasoning briefly."
  it.user "If a train goes 60 mph for 1.5 hours, how far does it travel?"
  it.user "Now double the speed for the same time."
end
bot.chat(prompt)
```

## Features

#### General
- ✅  Unified API across providers
- 📦  Zero runtime deps (stdlib-only)
- 🧩  Pluggable JSON adapters (JSON, Oj, Yajl, etc)
- 🧱  Builtin tracer API ([LLM::Tracer](https://rubydoc.info/github/llmrb/llm.rb/LLM/Tracer.html))

#### Optionals

- ♻️  Optional persistent HTTP pool ([net-http-persistent](https://github.com/drbrain/net-http-persistent))
- 📈  Optional telemetry support via OpenTelemetry ([opentelemetry-sdk](https://github.com/open-telemetry/opentelemetry-ruby))
- 🪵  Optional logging support via Ruby's standard library ([ruby/logger](https://github.com/ruby/logger))

#### Chat, Agents
- 🧠  Stateless + stateful chat (completions + responses)
- 🤖  Tool calling / function execution
- 🔁  Agent tool-call auto-execution (bounded)
- 🗂️  JSON Schema structured output
- 📡  Streaming responses

#### Media
- 🗣️  TTS, transcription, translation
- 🖼️  Image generation + editing
- 📎  Files API + prompt-aware file inputs
- 📦  Streaming multipart uploads (no full buffering)
- 💡  Multimodal prompts (text, documents, audio, images, video, URLs)

#### Embeddings
- 🧮  Embeddings
- 🧱  OpenAI vector stores (RAG)

#### Miscellaneous
- 📜  Models API
- 🔧  OpenAI responses + moderations

## Matrix

| Feature / Provider                  | OpenAI | Anthropic | Gemini | DeepSeek | xAI (Grok) | zAI    | Ollama | LlamaCpp |
|--------------------------------------|:------:|:---------:|:------:|:--------:|:----------:|:------:|:------:|:--------:|
| **Chat Completions**                 | ✅     | ✅        | ✅     | ✅       | ✅         | ✅     | ✅     | ✅       |
| **Streaming**                        | ✅     | ✅        | ✅     | ✅       | ✅         | ✅     | ✅     | ✅       |
| **Tool Calling**                     | ✅     | ✅        | ✅     | ✅       | ✅         | ✅     | ✅     | ✅       |
| **JSON Schema / Structured Output**  | ✅     | ❌        | ✅     | ❌       | ✅         | ❌     | ✅*    | ✅*      |
| **Embeddings**                       | ✅     | ✅        | ✅     | ✅       | ❌         | ❌     | ✅     | ✅       |
| **Multimodal Prompts** *(text, documents, audio, images, videos, URLs, etc)* | ✅     | ✅        | ✅     | ✅       | ✅         | ❌     | ✅     | ✅       |
| **Files API**                        | ✅     | ✅        | ✅     | ❌       | ❌         | ❌     | ❌     | ❌       |
| **Models API**                       | ✅     | ✅        | ✅     | ✅       | ✅         | ❌     | ✅     | ✅       |
| **Audio (TTS / Transcribe / Translate)** | ✅  | ❌        | ✅     | ❌       | ❌         | ❌     | ❌     | ❌       |
| **Image Generation & Editing**       | ✅     | ❌        | ✅     | ❌       | ✅         | ❌     | ❌     | ❌       |
| **Local Model Support**              | ❌     | ❌        | ❌     | ❌       | ❌         | ❌     | ✅     | ✅       |
| **Vector Stores (RAG)**               | ✅     | ❌        | ❌     | ❌       | ❌         | ❌     | ❌     | ❌       |
| **Responses**                        | ✅     | ❌        | ❌     | ❌       | ❌         | ❌     | ❌     | ❌       |
| **Moderations**                      | ✅     | ❌        | ❌     | ❌       | ❌         | ❌     | ❌     | ❌       |

\* JSON Schema support in Ollama/LlamaCpp depends on the model, not the API.


## Examples

### Providers

#### LLM::Provider

All providers inherit from [LLM::Provider](https://rubydoc.info/github/llmrb/llm.rb/LLM/Provider.html) &ndash;
they share a common interface and set of functionality. Each provider can be instantiated
using an API key (if required) and an optional set of configuration options via
[the singleton methods of LLM](https://rubydoc.info/github/llmrb/llm.rb/LLM.html). For example:

```ruby
#!/usr/bin/env ruby
require "llm"

##
# remote providers
llm = LLM.openai(key: "yourapikey")
llm = LLM.gemini(key: "yourapikey")
llm = LLM.anthropic(key: "yourapikey")
llm = LLM.xai(key: "yourapikey")
llm = LLM.zai(key: "yourapikey")
llm = LLM.deepseek(key: "yourapikey")

##
# local providers
llm = LLM.ollama(key: nil)
llm = LLM.llamacpp(key: nil)
```

#### LLM::Response

All provider methods that perform requests return an
[LLM::Response](https://rubydoc.info/github/llmrb/llm.rb/LLM/Response.html).
If the HTTP response is JSON (`content-type: application/json`),
`response.body` is parsed into an
[LLM::Object](https://rubydoc.info/github/llmrb/llm.rb/LLM/Object.html) for
dot-access. For non-JSON responses, `response.body` is a raw string.
It is also possible to access top-level keys directly on the response
(eg: `res.object` instead of `res.body.object`):

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.models.all
puts res.object
puts res.data.first.id
```

#### Persistence

The llm.rb library can maintain a process-wide connection pool
for each provider that is instantiated. This feature can improve
performance but it is optional, the implementation depends on
[net-http-persistent](https://github.com/drbrain/net-http-persistent),
and the gem should be installed separately:

```ruby
#!/usr/bin/env ruby
require "llm"

llm  = LLM.openai(key: ENV["KEY"], persistent: true)
res1 = llm.responses.create "message 1"
res2 = llm.responses.create "message 2", previous_response_id: res1.response_id
res3 = llm.responses.create "message 3", previous_response_id: res2.response_id
puts res3.output_text
```

#### Telemetry

The llm.rb library includes telemetry support through its tracer API, and it
can be used to trace LLM requests. It can be useful for debugging, monitoring,
and observability. The primary use case in mind is integration with tools like
[LangSmith](https://www.langsmith.com/).

The telemetry implementation uses the [opentelemetry-sdk](https://github.com/open-telemetry/opentelemetry-ruby)
and is based on the [gen-ai telemetry spec(s)](https://github.com/open-telemetry/semantic-conventions/blob/main/docs/gen-ai/).
This feature is optional, disabled by default, and the [opentelemetry-sdk](https://github.com/open-telemetry/opentelemetry-ruby)
gem should be installed separately. Please also note that llm.rb will take care of
loading and configuring the [opentelemetry-sdk](https://github.com/open-telemetry/opentelemetry-ruby)
library for you, and llm.rb configures an in-memory exporter that doesn't have
external dependencies by default:

```ruby
#!/usr/bin/env ruby
require "llm"
require "pp"

llm = LLM.openai(key: ENV["KEY"])
llm.tracer = LLM::Tracer::Telemetry.new(llm)

bot = LLM::Bot.new(llm)
bot.chat "Hello world!"
bot.chat "Adios."
bot.tracer.spans.each { |span| pp span }
```

#### Logger

The llm.rb library includes simple logging support through its
tracer API, and Ruby's standard library ([ruby/logger](https://github.com/ruby/logger)).
This feature is optional, disabled by default, and it can be useful for debugging and/or
monitoring requests to LLM providers. The `file` option can be used to choose where logs
are written to, and by default it is set to `$stdout`:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["OPENAI_SECRET"])
llm.tracer = LLM::Tracer::Logger.new(llm, file: $stdout)

bot = LLM::Bot.new(llm)
bot.chat "Hello world!"
bot.chat "Adios."
```

#### Thread Safety

The llm.rb library is thread-safe and can be used in a multi-threaded
environments but it is important to keep in mind that the
[LLM::Provider](https://rubydoc.info/github/llmrb/llm.rb/LLM/Provider.html)
and
[LLM::Bot](https://rubydoc.info/github/llmrb/llm.rb/LLM/Bot.html)
classes should be instantiated once per thread, and not shared
between threads. Generally the library tries to avoid global or
shared state but where it exists reentrant locks are used to
ensure thread-safety.

### Tools

#### LLM::Function

The following example demonstrates [LLM::Function](https://rubydoc.info/github/llmrb/llm.rb/LLM/Function.html)
and how it can define a local function (which happens to be a tool), and how
a provider (such as OpenAI) can then detect when we should call the function.
Its most notable feature is that it can act as a closure and has access to
its surrounding scope, which can be useful in some situations:

```ruby
#!/usr/bin/env ruby
require "llm"

llm  = LLM.openai(key: ENV["KEY"])
tool = LLM.function(:system) do |fn|
  fn.description "Run a shell command"
  fn.params do |schema|
    schema.object(command: schema.string.required)
  end
  fn.define do |command:|
    ro, wo = IO.pipe
    re, we = IO.pipe
    Process.wait Process.spawn(command, out: wo, err: we)
    [wo,we].each(&:close)
    {stderr: re.read, stdout: ro.read}
  end
end

bot = LLM::Bot.new(llm, tools: [tool])
bot.chat "Your task is to run shell commands via a tool.", role: :user

bot.chat "What is the current date?", role: :user
bot.chat bot.functions.map(&:call) # report return value to the LLM

bot.chat "What operating system am I running?", role: :user
bot.chat bot.functions.map(&:call) # report return value to the LLM

##
# {stderr: "", stdout: "Thu May  1 10:01:02 UTC 2025"}
# {stderr: "", stdout: "FreeBSD"}
```

#### LLM::Tool

The [LLM::Tool](https://rubydoc.info/github/llmrb/llm.rb/LLM/Tool.html) class can be used
to implement a [LLM::Function](https://rubydoc.info/github/llmrb/llm.rb/LLM/Function.html)
as a class. Under the hood, a subclass of [LLM::Tool](https://rubydoc.info/github/llmrb/llm.rb/LLM/Tool.html)
wraps an instance of [LLM::Function](https://rubydoc.info/github/llmrb/llm.rb/LLM/Function.html)
and delegates to it.

The choice between [LLM::Function](https://rubydoc.info/github/llmrb/llm.rb/LLM/Function.html)
and [LLM::Tool](https://rubydoc.info/github/llmrb/llm.rb/LLM/Tool.html) is often a matter of
preference but each carry their own benefits. For example, [LLM::Function](https://rubydoc.info/github/llmrb/llm.rb/LLM/Function.html)
has the benefit of being a closure that has access to its surrounding context and
sometimes that is useful:

```ruby
#!/usr/bin/env ruby
require "llm"

class System < LLM::Tool
  name "system"
  description "Run a shell command"
  param :command, String, "The command to execute", required: true

  def call(command:)
    ro, wo = IO.pipe
    re, we = IO.pipe
    Process.wait Process.spawn(command, out: wo, err: we)
    [wo,we].each(&:close)
    {stderr: re.read, stdout: ro.read}
  end
end

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm, tools: [System])
bot.chat "Your task is to run shell commands via a tool.", role: :user

bot.chat "What is the current date?", role: :user
bot.chat bot.functions.map(&:call) # report return value to the LLM

bot.chat "What operating system am I running?", role: :user
bot.chat bot.functions.map(&:call) # report return value to the LLM

##
# {stderr: "", stdout: "Thu May  1 10:01:02 UTC 2025"}
# {stderr: "", stdout: "FreeBSD"}
```

### Files

#### Create

The OpenAI and Gemini providers provide a Files API where a client can upload files
that can be referenced from a prompt, and with other APIs as well. The following
example uses the OpenAI provider to describe the contents of a PDF file after
it has been uploaded. The file (a specialized instance of
[LLM::Response](https://rubydoc.info/github/llmrb/llm.rb/LLM/Response.html)
) is given as part of a prompt that is understood by llm.rb:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm)
file = llm.files.create(file: "/tmp/llm-book.pdf")
res = bot.chat ["Tell me about this file", file]
res.messages.each { |m| puts "[#{m.role}] #{m.content}" }
```

### Prompts

#### Multimodal

LLMs are great with text, but many can also handle images, audio, video,
and URLs. With llm.rb you pass those inputs by tagging them with one of
the following methods. And for multipart prompts, we can pass an array
where each element is a part of the input. See the example below for
details, in the meantime here are the methods to know for multimodal
inputs:

* `bot.image_url` for an image URL
* `bot.local_file` for a local file
* `bot.remote_file` for a file already uploaded via the provider's Files API

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm)
res = bot.chat ["Tell me about this image URL", bot.image_url(url)]
res = bot.chat ["Tell me about this PDF", bot.remote_file(file)]
res = bot.chat ["Tell me about this image", bot.local_file(path)]}
```

### Audio

#### Speech

Some but not all providers implement audio generation capabilities that
can create speech from text, transcribe audio to text, or translate
audio to text (usually English). The following example uses the OpenAI provider
to create an audio file from a text prompt. The audio is then moved to
`${HOME}/hello.mp3` as the final step:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.audio.create_speech(input: "Hello world")
IO.copy_stream res.audio, File.join(Dir.home, "hello.mp3")
```

#### Transcribe

The following example transcribes an audio file to text. The audio file
(`${HOME}/hello.mp3`) was theoretically created in the previous example,
and the result is printed to the console. The example uses the OpenAI
provider to transcribe the audio file:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.audio.create_transcription(
  file: File.join(Dir.home, "hello.mp3")
)
puts res.text # => "Hello world."
```

#### Translate

The following example translates an audio file to text. In this example
the audio file (`${HOME}/bomdia.mp3`) is theoretically in Portuguese,
and it is translated to English. The example uses the OpenAI provider,
and at the time of writing, it can only translate to English:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.audio.create_translation(
  file: File.join(Dir.home, "bomdia.mp3")
)
puts res.text # => "Good morning."
```

### Images

#### Create

Some but not all LLM providers implement image generation capabilities that
can create new images from a prompt, or edit an existing image with a
prompt. The following example uses the OpenAI provider to create an
image of a dog on a rocket to the moon. The image is then moved to
`${HOME}/dogonrocket.png` as the final step:

```ruby
#!/usr/bin/env ruby
require "llm"
require "open-uri"
require "fileutils"

llm = LLM.openai(key: ENV["KEY"])
res = llm.images.create(prompt: "a dog on a rocket to the moon")
res.urls.each do |url|
  FileUtils.mv OpenURI.open_uri(url).path,
               File.join(Dir.home, "dogonrocket.png")
end
```

#### Edit

The following example is focused on editing a local image with the aid
of a prompt. The image (`/tmp/llm-logo.png`) is returned to us with a hat.
The image is then moved to `${HOME}/logo-with-hat.png` as
the final step:

```ruby
#!/usr/bin/env ruby
require "llm"
require "open-uri"
require "fileutils"

llm = LLM.openai(key: ENV["KEY"])
res = llm.images.edit(
  image: "/tmp/llm-logo.png",
  prompt: "add a hat to the logo",
)
res.urls.each do |url|
  FileUtils.mv OpenURI.open_uri(url).path,
               File.join(Dir.home, "logo-with-hat.png")
end
```

#### Variations

The following example is focused on creating variations of a local image.
The image (`/tmp/llm-logo.png`) is returned to us with five different variations.
The images are then moved to `${HOME}/logo-variation0.png`, `${HOME}/logo-variation1.png`
and so on as the final step:

```ruby
#!/usr/bin/env ruby
require "llm"
require "open-uri"
require "fileutils"

llm = LLM.openai(key: ENV["KEY"])
res = llm.images.create_variation(
  image: "/tmp/llm-logo.png",
  n: 5
)
res.urls.each.with_index do |url, index|
  FileUtils.mv OpenURI.open_uri(url).path,
               File.join(Dir.home, "logo-variation#{index}.png")
end
```

### Embeddings

#### Text

The
[`LLM::Provider#embed`](https://rubydoc.info/github/llmrb/llm.rb/LLM/Provider.html#embed-instance_method)
method returns vector embeddings for one or more text inputs. A common
use is semantic search (store vectors, then query for similar text):

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
res = llm.embed(["programming is fun", "ruby is a programming language", "sushi is art"])
puts res.class
puts res.embeddings.size
puts res.embeddings[0].size

##
# LLM::Response
# 3
# 1536
```

### Models

#### List

Almost all LLM providers provide a models endpoint that allows a client to
query the list of models that are available to use. The list is dynamic,
maintained by LLM providers, and it is independent of a specific llm.rb
release:

```ruby
#!/usr/bin/env ruby
require "llm"

##
# List all models
llm = LLM.openai(key: ENV["KEY"])
llm.models.all.each do |model|
  puts "model: #{model.id}"
end

##
# Select a model
model = llm.models.all.find { |m| m.id == "gpt-3.5-turbo" }
bot = LLM::Bot.new(llm, model: model.id)
res = bot.chat "Hello #{model.id} :)"
res.messages.each { |m| puts "[#{m.role}] #{m.content}" }
```

## Install

llm.rb can be installed via rubygems.org:

	gem install llm.rb

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)
