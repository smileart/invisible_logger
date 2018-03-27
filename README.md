# 🕵🏻‍ InvisibleLogger

<p align="center">
  <img width="460" title="hero" src ="./img/invisible_logger.png" />
</p>

> [![Build Status](https://travis-ci.org/smileart/invisible_logger.svg?branch=master)](https://travis-ci.org/smileart/invisible_logger) [![Gem](https://img.shields.io/gem/v/invisible_logger.svg)](https://rubygems.org/gems/invisible_logger)

> A tool to output complex logs with minimal intrusion and smallest possible footprint in the "host" code + additional ability to aggregate separate logs.

You know how sometimes one can't see the wood for the trees? The same happens with an extensive logging, when long or even multiline logs polute your code and it's hard to see the business logic behind all the noise they create. InvisibleLogger is an attempt to solve this issue.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'invisible_logger'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install invisible_logger

## Usage

Have you ever encountered the situation when you can hardly see the business logic behind the logging? Let's consider an example:

```ruby
# 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧

class SomeService
  def initialize(api_key, logger)
    logger.info "Service → count#auth_attempt=1"
    logger.info "Trying to login with the API key: #{api_key}" if ENV['DEBUG']

    auth_result = ThirdPartyAPI.auth(api_key)

    if auth_result[:status] == :success
      @tmp_token = auth_result[:auth_token]

      logger.info %W[
          Service → Authentication was successful! ::
          Status: #{auth_result[:status]} ::
          API Version: #{auth_result[:api_version]} ::
          Temporary token: #{auth_result[:auth_token]}
      ].join ' '
    else
      logger.error %W[
          Service → count#auth_errors=1 ::
          Authentication failed with status #{auth_result[:status]} ::
          Error code: #{auth_result[:error_code]} ::
          Error message: #{auth_result[:error_message]}
      ].join ' '

      raise ThirdPartyAPIAuthError, auth_result[:error_message]
    end
  end
end

# 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧
```

With InvisibleLogger you'd be able to refactor it into something like this:

```ruby
# 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧

class SomeService
  include LogStencils::SomeService

  def initialize(api_key, logger)
    @il = InvisibleLogger.new(logger: logger, log_stencil: LOG_STENCIL)

    @il.l(binding, :auth_attempt)
    @il.l(binding, :debug_api_key) if ENV['DEBUG']

    auth_result = ThirdPartyAPI.auth(api_key)

    if auth_result[:status] == :success
      @tmp_token = auth_result[:auth_token]
      @il.l(binding, :success)
    else
      @il.l(binding, :failure)
      raise ThirdPartyAPIAuthError, auth_result[:error_message]
    end
  end
end

# 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧 🚧
```

While the log messages themselves live in a separate dedicated place (*but, don't worry about any context lose, InvisibleLogger has DEBUG mode and customisable markers for each messag, plus error messages about wrong var names are quite readable*):

```ruby
module LogStencils
 module SomeService
	LOG_STENCIL = {
	    auth_attempt: {
	      level: :info,
	      template: <<~LOG
           Service → count#auth_attempt=1
	      LOG
	    },
	    debug_api_key: {
	      vars: [: api_key],
	      level: :info,
	      template: <<~LOG
	        Trying to login with the API key: %<api_key>s
	      LOG
	    },
	    success: {
	      vars: [
	        { status: 'auth_result[:status]' },
	        { api_version: 'auth_result[:api_version]' },
	        { tmp_token: 'auth_result[:auth_token]' }
	      ],
	      level: :info,
	      template: <<~LOG
	        Service → Authentication was successful! ::|
           Status: %<status>s ::|
           API Version: %<api_version>s ::|
           Temporary token: %<tmp_token>s
	      LOG
	    },
	    failure: {
	      vars: [
	        { status:    'auth_result[:status]' },
	        { err_code:  'auth_result[:error_code]' },
	        { err_msg:   'auth_result[:error_message]' }
	      ],
	      level: :error,
	      template: <<~LOG
	        Service → count#auth_errors=1 ::
           Authentication failed with status %<status>s ::
           Error code: %<err_code>s ::
           Error message: %<err_msg>s
	      LOG
	    }
    }
  end
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/smileart/invisible_logger. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the InvisibleLogger project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/smileart/invisible_logger/blob/master/CODE_OF_CONDUCT.md).
