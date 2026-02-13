> **Minimal footprint** <br>
> Zero dependencies outside Ruby’s standard library. <br>
> Zero runtime dependencies.

## About

llm.rb is a zero-dependency Ruby toolkit for Large Language Models that
includes OpenAI, Gemini, Anthropic, xAI (Grok), zAI, DeepSeek, Ollama,
and LlamaCpp. The toolkit includes full support for chat, streaming,
tool calling, audio, images, files, and structured outputs.

## Quick start

#### REPL

A simple chatbot that maintains a conversation and streams responses in real-time:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV.fetch("KEY"))
bot = LLM::Bot.new(llm, stream: $stdout)
loop do
  print "> "
  bot.chat(STDIN.gets)
  puts
end
```

#### Prompts

> ℹ️  **Tip:** Some providers (such as OpenAI) support `system` and `developer`
> roles, but the examples in this README stick to `user` roles since they are
> supported across all providers.

A prompt builder that produces a chain of messages that can be sent in one request:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV.fetch("KEY"))
bot = LLM::Bot.new(llm)

prompt = bot.build_prompt do
  it.user "Answer concisely."
  it.user "Was 2024 a leap year?"
  it.user "How many days were in that year?"
end

res = bot.chat(prompt)
res.choices.each { |m| puts "[#{m.role}] #{m.content}" }
```

#### Schema

A bot that instructs the LLM to respond in JSON, and according to the given schema:

```ruby
#!/usr/bin/env ruby
require "llm"

class Estimation < LLM::Schema
  property :age, Integer, "Estimated age", required: true
  property :confidence, Number, "0.0–1.0", required: true
  property :notes, String, "Short notes", optional: true
end

llm = LLM.openai(key: ENV.fetch("KEY"))
bot = LLM::Bot.new(llm, schema: Estimation)
img = llm.images.create(prompt: "A man in his 30s")
res = bot.chat bot.image_url(img.urls.first)
data = res.choices.find(&:assistant?).content!

puts "age: #{data["age"]}"
puts "confidence: #{data["confidence"]}"
puts "notes: #{data["notes"]}" if data["notes"]
```

#### Tools

A bot equipped with a tool that is capable of running system commands:

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

llm  = LLM.openai(key: ENV.fetch("KEY"))
bot  = LLM::Bot.new(llm, tools: [System])

prompt = bot.build_prompt do
  it.user "You can run safe shell commands."
  it.user "Run `date`."
end

bot.chat(prompt)
bot.chat(bot.functions.map(&:call))
bot.messages.select(&:assistant?).each { |m| puts "[#{m.role}] #{m.content}" }
```

## Features

#### General
- ✅  Unified API across providers
- 📦  Zero runtime deps (stdlib-only)
- 🧩  Pluggable JSON adapters (JSON, Oj, Yajl, etc)
- ♻️  Optional persistent HTTP pool (net-http-persistent)
- 🧭  Built-in tracing primitives for eval frameworks

#### Chat, Agents
- 🧠  Stateless + stateful chat (completions + responses)
- 🤖  Tool calling / function execution
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

All providers inherit from [LLM::Provider](https://0x1eef.github.io/x/llm.rb/LLM/Provider.html) &ndash;
they share a common interface and set of functionality. Each provider can be instantiated
using an API key (if required) and an optional set of configuration options via
[the singleton methods of LLM](https://0x1eef.github.io/x/llm.rb/LLM.html). For example:

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
[LLM::Response](https://0x1eef.github.io/x/llm.rb/LLM/Response.html).
If the HTTP response is JSON (`content-type: application/json`),
`response.body` is parsed into an
[LLM::Object](https://0x1eef.github.io/x/llm.rb/LLM/Object.html) for
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

#### Thread Safety

The llm.rb library is thread-safe and can be used in a multi-threaded
environments but it is important to keep in mind that the
[LLM::Provider](https://0x1eef.github.io/x/llm.rb/LLM/Provider.html)
and
[LLM::Bot](https://0x1eef.github.io/x/llm.rb/LLM/Bot.html)
classes should be instantiated once per thread, and not shared
between threads. Generally the library tries to avoid global or
shared state but where it exists reentrant locks are used to
ensure thread-safety.

### Conversations

#### Completions

The following example creates an instance of
[LLM::Bot](https://0x1eef.github.io/x/llm.rb/LLM/Bot.html)
and enters into a conversation where each call to "bot.chat" immediately
sends a request to the provider, updates the conversation history, and
returns an [LLM::Response](https://0x1eef.github.io/x/llm.rb/LLM/Response.html).
The full conversation history is automatically included in
each subsequent request:

```ruby
#!/usr/bin/env ruby
require "llm"

llm  = LLM.openai(key: ENV["KEY"])
bot  = LLM::Bot.new(llm)
image_url = "https://upload.wikimedia.org/wikipedia/commons/9/97/The_Earth_seen_from_Apollo_17.jpg"
image_path = "/tmp/llm-logo.png"
pdf_path = "/tmp/llm-handbook.pdf"

prompt = bot.build_prompt do
  it.user ["Tell me about this image", bot.image_url(image_url)]
  it.user ["Tell me about this image", bot.local_file(image_path)]
  it.user ["Tell me about this PDF", bot.local_file(pdf_path)]
end
bot.chat(prompt)
bot.messages.each { |m| puts "[#{m.role}] #{m.content}" }
```

#### Streaming

The following example streams the messages in a conversation
as they are generated in real-time. The `stream` option can
be set to an IO object, or the value `true` to enable streaming.
When streaming, the `bot.chat` method will block until the entire
stream is received. At the end, it returns the `LLM::Response` object
containing the full aggregated content:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm, stream: $stdout)
image_url = "https://upload.wikimedia.org/wikipedia/commons/9/97/The_Earth_seen_from_Apollo_17.jpg"
image_path = "/tmp/llm-logo.png"
pdf_path = "/tmp/llm-handbook.pdf"

prompt = bot.build_prompt do
  it.user ["Tell me about this image", bot.image_url(image_url)]
  it.user ["Tell me about this image", bot.local_file(image_path)]
  it.user ["Tell me about the PDF", bot.local_file(pdf_path)]
end
bot.chat(prompt)
```

#### Tracer

The following example demonstrates how to use the built-in tracing primitives
to capture spans and events for a chat interaction. This can be useful for
debugging, logging, or feeding into an eval framework:

```ruby
require "llm"

llm = LLM.openai(key: ENV["OPENAI_SECRET"], trace: true)
bot = LLM::Bot.new(llm)
bot.chat "Hello world"
pp bot.tracer.to_h
```

### Schema

All LLM providers except Anthropic and DeepSeek allow a client to describe
the structure of a response that a LLM emits according to a schema that is
described by JSON. The schema lets a client describe what JSON object
an LLM should emit, and the LLM will abide by the schema to the best of
its ability:

```ruby
#!/usr/bin/env ruby
require "llm"

class Player < LLM::Schema
  property :name, String, "The player's name", required: true
  property :position, Array[Number], "The player's [x, y] position", required: true
end

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm, schema: Player)
prompt = bot.build_prompt do
  it.user "The player's name is Sam and their position is (7, 12)."
  it.user "Return the player's name and position"
end

player = bot.chat(prompt).content!
puts "name: #{player['name']}"
puts "position: #{player['position'].join(', ')}"
```

### Tools

#### Introduction

All providers support a powerful feature known as tool calling, and although
it is a little complex to understand at first, it can be powerful for building
agents. There are three main interfaces to understand: [LLM::Function](https://0x1eef.github.io/x/llm.rb/LLM/Function.html),
[LLM::Tool](https://0x1eef.github.io/x/llm.rb/LLM/Tool.html), and
[LLM::ServerTool](https://0x1eef.github.io/x/llm.rb/LLM/ServerTool.html).


#### LLM::Function

The following example demonstrates [LLM::Function](https://0x1eef.github.io/x/llm.rb/LLM/Function.html)
and how it can define a local function (which happens to be a tool), and how
a provider (such as OpenAI) can then detect when we should call the function.
Its most notable feature is that it can act as a closure and has access to
its surrounding scope, which can be useful in some situations.

The
[LLM::Bot#functions](https://0x1eef.github.io/x/llm.rb/LLM/Bot.html#functions-instance_method)
method returns an array of functions that can be called after a `chat` interaction
if the LLM detects a function should be called. You would then typically call these
functions and send their results back to the LLM in a subsequent `chat` call:

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

bot.chat "What operating system am I running? (short version please!)", role: :user
bot.chat bot.functions.map(&:call) # report return value to the LLM

##
# {stderr: "", stdout: "Thu May  1 10:01:02 UTC 2025"}
# {stderr: "", stdout: "FreeBSD"}
```

#### LLM::Tool

The [LLM::Tool](https://0x1eef.github.io/x/llm.rb/LLM/Tool.html) class can be used
to implement a [LLM::Function](https://0x1eef.github.io/x/llm.rb/LLM/Function.html)
as a class. Under the hood, a subclass of [LLM::Tool](https://0x1eef.github.io/x/llm.rb/LLM/Tool.html)
wraps an instance of [LLM::Function](https://0x1eef.github.io/x/llm.rb/LLM/Function.html)
and delegates to it.

The choice between [LLM::Function](https://0x1eef.github.io/x/llm.rb/LLM/Function.html)
and [LLM::Tool](https://0x1eef.github.io/x/llm.rb/LLM/Tool.html) is often a matter of
preference but each carry their own benefits. For example, [LLM::Function](https://0x1eef.github.io/x/llm.rb/LLM/Function.html)
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

bot.chat "What operating system am I running? (short version please!)", role: :user
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
[LLM::Response](https://0x1eef.github.io/x/llm.rb/LLM/Response.html)
) is given as part of a prompt that is understood by llm.rb:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm)
file = llm.files.create(file: "/tmp/llm-book.pdf")
res = bot.chat ["Tell me about this file", file]
res.choices.each { |m| puts "[#{m.role}] #{m.content}" }
```

### Prompts

#### Multimodal

While LLMs inherently understand text, they can also process and
generate other types of media such as audio, images, video, and
even URLs. To provide these multimodal inputs to the LLM, llm.rb
uses explicit tagging methods on the `LLM::Bot` instance.
These methods wrap your input into a special `LLM::Object`,
clearly indicating its type and intent to the underlying LLM
provider.

For instance, to specify an image URL, you would use
`bot.image_url`. For a local file, `bot.local_file`. For an
already uploaded file managed by the LLM provider's Files API,
`bot.remote_file`. This approach ensures clarity and allows
llm.rb to correctly format the input for each provider's
specific requirements.

An array can be used for a prompt with multiple parts, where each
element contributes to the overall input:

```ruby
#!/usr/bin/env ruby
require "llm"

llm = LLM.openai(key: ENV["KEY"])
bot = LLM::Bot.new(llm)
image_url = "https://upload.wikimedia.org/wikipedia/commons/9/97/The_Earth_seen_from_Apollo_17.jpg"
image_path = "/tmp/llm-logo.png"
pdf_path = "/tmp/llm-book.pdf"

res1 = bot.chat ["Tell me about this image URL", bot.image_url(image_url)]
res1.choices.each { |m| puts "[#{m.role}] #{m.content}" }

file = llm.files.create(file: pdf_path)
res2 = bot.chat ["Tell me about this PDF", bot.remote_file(file)]
res2.choices.each { |m| puts "[#{m.role}] #{m.content}" }

res3 = bot.chat ["Tell me about this image", bot.local_file(image_path)]
res3.choices.each { |m| puts "[#{m.role}] #{m.content}" }
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
[`LLM::Provider#embed`](https://0x1eef.github.io/x/llm.rb/LLM/Provider.html#embed-instance_method)
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
res.choices.each { |m| puts "[#{m.role}] #{m.content}" }
```

## Install

llm.rb can be installed via rubygems.org:

	gem install llm.rb

## License

[BSD Zero Clause](https://choosealicense.com/licenses/0bsd/)
<br>
See [LICENSE](./LICENSE)
