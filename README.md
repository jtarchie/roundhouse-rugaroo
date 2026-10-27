# roundhouse-rugaroo

[Roundhouse](https://rubys.github.io/roundhouse/) turns a Rails app into plain
Ruby with no Rails left in it (`roundhouse --target spinel`), written for the
[Spinel](https://github.com/matz/spinel) compiler. This gem lets that output run
anywhere else:

- on **MRI**, as an ordinary Ruby program;
- compiled by **[rugaroo](https://github.com/jtarchie/rugaroo)** into one Go
  binary.

A few files in roundhouse's output call C through Spinel's FFI: its HTTP server
(tep), its sqlite binding and two crypto helpers. This gem provides each of them
in Ruby, plus the RBS types rugaroo needs where roundhouse's own `.rbs` files are
loose. The generated app itself is used as roundhouse wrote it.

## Getting started

Needs Ruby 4.0, Go, and the `sqlite3` command line tool. The commands are for
macOS on Apple silicon.

```sh
# Tools
gem install rails -v 8.1.4
go install github.com/jtarchie/rugaroo/cmd/rugaroo@main
gh release download v2026.9.18 -R rubys/roundhouse -p 'roundhouse-aarch64-apple-darwin.tar.xz'
tar xf roundhouse-aarch64-apple-darwin.tar.xz
export PATH="$PWD/roundhouse-aarch64-apple-darwin:$(go env GOPATH)/bin:$PATH"

# A Rails app
rails _8.1.4_ new myblog --skip-git --skip-docker --skip-test --skip-system-test
cd myblog
bin/rails generate scaffold Post title:string body:text
bin/rails db:migrate
sed -i '' 's/^  # root "posts#index"/  root "posts#index"/' config/routes.rb   # roundhouse needs a root route
sed -i '' '/rails\/health#show/d' config/routes.rb                          # and does not emit Rails' /up health check
cd ..

# Rails → plain Ruby
roundhouse --target spinel -o myblog-go/blog myblog

# Plain Ruby → one Go binary
cd myblog-go
cat > Gemfile <<'EOF'
source "https://rubygems.org"
gem "roundhouse-rugaroo", github: "jtarchie/roundhouse-rugaroo"
EOF
bundle install
cat > serve.rb <<'EOF'
# nil_check: runtime
$LOADED_FEATURES << File.expand_path("blog/runtime/tep/tep.rb", __dir__)
$LOADED_FEATURES << File.expand_path("blog/runtime/db.rb", __dir__)
$LOAD_PATH.unshift(File.expand_path("blog/runtime", __dir__))
ENV["BUNDLE_GEMFILE"] = File.expand_path("Gemfile", __dir__)
require "bundler/setup"
require "roundhouse/rugaroo"

ENV["BLOG_DB"] ||= File.expand_path("blog.sqlite3", __dir__)
Tep.on_listen(lambda { |_port| nil }) if ENV["PORT"].nil? # `rugaroo build -trace` runs this once: boot, then stop

require_relative "blog/runtime/importmap"
require_relative "blog/config/importmap"
require_relative "blog/main"
EOF
sqlite3 blog.sqlite3 < blog/db/seed.sql
rugaroo build -trace -o myblog serve.rb

# Run it, compiled or on MRI
PORT=3000 ./myblog          # then open http://localhost:3000/posts
PORT=3000 ruby serve.rb
```

`PORT` must be set: without it the program boots and stops, which is how
`rugaroo build -trace` runs it once under MRI to see what it loads.

## What `serve.rb` does

- The two `$LOADED_FEATURES` lines mark roundhouse's tep server and FFI sqlite
  files as loaded, so the app's own `require_relative`s skip them and this gem's
  versions stand in. rugaroo honours the same lines at compile time.
- `bundler/setup` finds this gem through the `Gemfile` beside `serve.rb`, as a
  Rails app's `config/boot.rb` does.
- `blog/runtime/` goes on `$LOAD_PATH`: the gem reuses tep's own pure-Ruby
  request parser from there, and rugaroo compiles that directory as it compiles
  a gem (only what the app reaches).
- `# nil_check: runtime`: the emitted code uses possibly-nil values where it
  knows they are not nil, as Ruby lets it; rugaroo checks those at run time.
- The importmap files load before the app. Roundhouse's boot loads the views,
  whose layout computes the importmap tags once, before the app's importmap, so
  on MRI the layout would otherwise get the runtime's empty default.

## What is in the gem

| File | Stands in for |
|---|---|
| `lib/roundhouse/rugaroo/tep.rb` | `runtime/tep/` (tep, Spinel's HTTP server): `Tep::Request`, `Tep::Response`, `Tep::APP.dispatch` and `Tep::Server::Threaded#run`, on `TCPServer` with one thread per connection and HTTP/1.1 keep-alive. |
| `lib/roundhouse/rugaroo/db.rb` | `runtime/db.rb` (sqlite through Spinel's FFI): the same `Db` API on the `sqlite3` gem, which rugaroo compiles as [sqlite3-fiddle](https://github.com/jtarchie/sqlite3-fiddle). |
| `lib/roundhouse/rugaroo/ffi.rb` | the `ffi_func` lines in `runtime/message_digest.rb` and `runtime/csrf_token.rb`: `ffi_func` does nothing, and the functions they declare are written in Ruby. |
| `sig/` | Types roundhouse's `.rbs` files leave to Spinel: `Roundhouse::ParamValue`, `ActiveRecord.adapter`, `Base.find -> instance`, the request path in `main.rb`, `Broadcasts::TRANSPORTS`. rugaroo reads a gem's `sig/` before the `.rbs` files beside the app's sources. |

## Not yet

- **CSS and JavaScript**: `/assets/*` answers 404, so pages are unstyled.
  Roundhouse's Spinel output expects a separate assets build. Forms still work,
  because they post normally.
- **Action Cable**: a WebSocket upgrade answers 501, so Turbo Stream broadcasts
  reach no browser.
- Checked against roundhouse 2026.9.18 with a Rails 8.1.4 scaffold and
  roundhouse's own Blog app (rugaroo's example 135).

## License

MIT.
