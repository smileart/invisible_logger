# frozen_string_literal: true
# encoding: UTF-8

# A tool to output complex logs with minimal intrusion and smallest possible
# footprint in the "host" code + additional ability to aggregate separate logs
class InvisibleLogger
  # Lib Semantic Version Constant
  VERSION = '0.1.1'

  # Read-only content of the buffered logs
  # @see #buffer
  attr_reader :aggregator

  # Read-only "level" the aggregated log is going to be flushed with
  # @see Logger
  # @see #level
  attr_reader :log_level

  # Create new invisible logger instance
  #
  # @note Use `INV_LOGGER_DEBUG` env var to enable global debug mode
  # @note Use `INV_LOGGER_DEBUG_MARKER` env var to change default debug marker
  #
  # @example
  #   LOG_STENCIL = {
  #     sum: {
  #       vars: [:a, :b, :@sum],
  #       level: :debug,
  #       template: <<~LOG
  #         %<a>s +|
  #         %<b>s → |
  #         %<@sum>s
  #         Splendid! Magnificent!
  #       LOG
  #     },
  #     warning: {
  #       vars: [:text],
  #       level: :warn,
  #       template: '>>>>>>> %<text>s'
  #     },
  #     additional_info: {
  #       template: "Additional INFO and nothing more... 👐"
  #     },
  #     eval_example: {
  #       vars: { const: 'self.class.const_get(:LOG_STENCIL)' },
  #       template: 'We can log constants and method calls:: %<const>s'
  #     }
  #   }
  #
  #   ENV['INV_LOGGER_DEBUG'] = '1'
  #   ENV['INV_LOGGER_DEBUG_MARKER'] = '🚀  '
  #
  #   class Test
  #     include TestLogStencil
  #
  #     def initialize
  #       @logger = Logger.new(STDOUT)
  #       @il     = InvisibleLogger.new(logger: @logger, log_stencil: LOG_STENCIL)
  #
  #       @sum   = '42 (Wonderful! Glorious!)'
  #     end
  #
  #     def sum(a, b)
  #       a + b
  #       @il.l(binding, :sum, aggregate: true)
  #     end
  #
  #     def one(text)
  #       @il.l(binding, :warning, aggregate: false, debug: true)
  #       @il.l(binding, :eval_example)
  #     end
  #
  #     def test
  #       @il.l(binding, :additional_info, aggregate: true)
  #       @il.f!
  #     end
  #   end
  #
  #   t = Test.new
  #   t.sum(2, 3)
  #   t.one('Beware of beavers!')
  #   t.test
  #
  # @param [Object] logger any object with standard Logger compartable interface
  # @param [Hash] log_stencil a Hash with the names, levels, templates and var lists (see example!)
  def initialize(logger:, log_stencil:)
    @logger      = logger
    @log_stencil = log_stencil

    @aggregator = ''
    @log_level  = :info

    @debug_marker = ENV['INV_LOGGER_DEBUG_MARKER'] || '▶️  '
  end

  # Log something
  #
  # @param [Binding] context pass the current context (aka binding)
  # @param [Symbol] name the name of the log stencil to use
  # @param [Boolean] aggregate should the logger aggregate this message or log (default: false)
  # @param [Boolean] debug the debug mode flag. Outputs the marker
  #                  and the name along with tht message (default: false)
  #
  # @note ⚠️ WARNING!!! Keep in mind that `debug` parameter could be overwritten with INV_LOGGER_DEBUG
  #       environment variable
  #
  # @raise [KeyError] if we work in debug mode
  # @return [Boolean] true if the message was logged successfully, false if the message wasn't logged
  #                   due to anny reason (including aggregation)
  def log(context, name, aggregate: false, debug: false)
    return unless context.respond_to?(:eval) && @log_stencil&.fetch(name, nil)

    @log_level, log_template, log_values = init_stencil_for(context, name, debug)

    log_text = render_log(log_template, log_values)

    aggregate ? accumulate(log_text) : flush(@log_level, log_text)
  rescue KeyError => e
    handle_template_error(e, debug)
  end

  # Flush the aggregated message and clean the accumulator var on success
  #
  # @note ⚠️ WARNING!!! This method empties the message accumulator on successfull log flushing
  # @note ⚠️ WARNING!!! Aggregated message will be logged with the level of the last stencil
  #
  # @return [String, Nil] empty String (latest aggregator state) of nil
  def flush!(dev_null = false)
    @aggregator = '' if dev_null || flush(@log_level, @aggregator)
  end

  # A short alias for the flush! method (to make the logging footprint even smaller)
  alias f! flush!

  # A short alias for the log method (to make the logging footprint even smaller)
  # @note Beware of potential letters gem incompartability http://lettersrb.com
  alias l log

  # An alias to get the content of the buffered logs
  alias buffer aggregator

  # An alias to get a level the aggregated log is going to be flushed with
  alias level log_level

  private

  # Flush the aggregated message if the level is supported by the Logger provided
  #
  # @return [Boolean] true if the level method is supported and called, false otherwise
  def flush(level, log)
    return if !log || log.empty?
    @logger.respond_to?(level) ? !@logger.send(level, log).nil? : false
  end

  # Stencil handling method — extracts level, template and vars, converts vars to String,
  # encodes them to UTF-8, links var names to the values from context
  # @see Ruby `format` method for template string / template values Hash reference
  #
  # @param [Binding] context context to evaluate vars/expression in
  # @param [Symbol] name the name of the log stencil
  # @param [Boolean] debug render template in debug mode
  #
  # @return [Array(Symbol, String, Hash)] returns and array of log_method (Symbol), log_template (template String),
  #                                       log_values (Hash for the template String)
  def init_stencil_for(context, name, debug = false)
    stencil = @log_stencil&.fetch(name)

    log_method   = stencil.fetch(:level, nil) || :info
    log_template = init_log_template(stencil, name, debug)
    log_values   = init_log_values(stencil, context)

    [log_method, log_template, log_values]
  end

  # Accumulate aggreagated log message and return false
  #
  # @param [String] message the message to put to the "aggregator" buffer
  #
  # @return [Boolean] false to return from log method (meaning nothing was logged to the output)
  def accumulate(message)
    @aggregator += " #{message}" if message
    false
  end

  # Fetch the template for the given name from the stencil + take the debug mode into account
  #
  # @param [Hash] stencil a Hash with the names, levels, templates and var lists (see example!)
  # @param [Symbol] name the name of the log stencil
  # @param [Boolean] debug render template in debug mode
  #
  # @return [String, Nil] fully prepared template string or nil
  def init_log_template(stencil, name, debug = false)
    log_template = stencil.fetch(:template, nil)
    log_template = debug || ENV['INV_LOGGER_DEBUG'] ? "#{@debug_marker}#{name} :: #{log_template}" : log_template
    log_template&.split("|\n")&.join(' ')&.strip
  end

  # Form log values to put into the template using given context
  #
  # @param [Hash] stencil a Hash with the names, levels, templates and var lists (see example!)
  # @param [Binding] context context to take vars/expression values from
  #
  # @return [Hash, Nil] Hash with all the values ready for `format` method or nil in case of no vars
  def init_log_values(stencil, context)
    log_values = {}
    log_vars   = stencil.fetch(:vars, [])

    log_vars.each do |v|
      if v.respond_to?(:each_pair)
        log_values[v.keys.first] = context.eval(v.values.first.to_s)
      else
        log_values[v] = context.eval(v.to_s)
      end
    end

    log_values = log_values.each_with_object({}) { |(k, v), h| h[k.to_sym] = v.to_s.dup.force_encoding('UTF-8') }

    log_values.empty? ? nil : log_values
  end

  # Render log message (fill template placeholders with the respective values) or receive a static String
  #
  # @param [String] template standard ruby tempalte string with named placeholders
  # @param [Hash] values standard ruby Hash with respective key names to fill placeholders
  #
  # @return [String] Rendered template string with filled placeholders filled with the respective values
  def render_log(template, values)
    template && values ? format(template, values) : template
  end

  # Handle log method exceptions (takes into account the debug mode)
  #
  # @param [Exception] exception the exception to handle
  #
  # @raise [KeyError] if we work in debug mode
  # @return [String] Rendered template string with filled placeholders filled with the respective values
  def handle_template_error(exception, debug = false)
    raise exception if debug || ENV['INV_LOGGER_DEBUG']
  end
end
