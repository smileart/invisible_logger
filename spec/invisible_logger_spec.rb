# frozen_string_literal: false

require 'logger'

require_relative 'spec_helper'
require_relative '../lib/invisible_logger'

def read_output(output)
  output.rewind
  output.read
end

RSpec.describe InvisibleLogger do
  HOBBIE = '🎳'.freeze

  let(:static_string_template) { 'Hello world!' }
  let(:binding_template) do
    <<~EULOGY
      And so, %<HOBBIE>s  %<name>s, in accordance with what we think your dying wishes might|
      well have been, we commit your final mortal remains to the bosom of the Pacific Ocean,|
      which you loved so well.
      Good night, sweet prince! %<date>s, %<@place>s'|
    EULOGY
  end

  let(:name) { 'Theodore Donald Kerabatsos' }

  let(:log_stencil) do
    {
      static_string: {
        level: :info,
        template: static_string_template
      },
      template_string: {
        vars: [:name, :@place, :HOBBIE, { date: 'Time.now' }],
        level: :warn,
        template: binding_template
      },
      multiline_template_string: {
        vars: [:name, :@place, :HOBBIE, { date: 'Time.now' }],
        level: :warn,
        template: binding_template.gsub("|\n", "\n")
      },
      unexisted_level: {
        level: :nihilistic,
        template: 'Life is totally meaningless!'
      },
      aggregation_example_1: {
        vars: %i[HOBBIE name],
        level: :info,
        template: binding_template.split("\n")[0].strip.tr('|', '')
      },
      aggregation_example_2: {
        level: :info,
        template: binding_template.split("\n")[1].tr('|', '').strip
      },
      aggregation_example_3: {
        level: :info,
        template: binding_template.split("\n")[2].tr('|', '').strip
      },
      aggregation_example_4: {
        vars: [{ date: 'Time.now' }, :@place],
        level: :error,
        template: binding_template.split("\n")[3].tr('|', '').strip
      },
      error_string: {
        vars: [:name],
        template: '%<nickname>s'
      }
    }
  end

  let(:info_log_prefix) do
    "I, [1991-09-19T00:00:00.000000 ##{Process.pid}]  INFO -- : "
  end

  let(:warning_log_prefix) do
    "W, [1991-09-19T00:00:00.000000 ##{Process.pid}]  WARN -- : "
  end

  let(:error_log_prefix) do
    "E, [1991-09-19T00:00:00.000000 ##{Process.pid}] ERROR -- : "
  end

  before :all do
    Timecop.freeze(Time.local(1991, 9, 19))
  end

  after :all do
    Timecop.return
  end

  before :each do
    @log_output = StringIO.new
    @logger     = Logger.new(@log_output)
    @il         = InvisibleLogger.new(logger: @logger, log_stencil: log_stencil)
  end

  it 'creates a new InvisibleLogger' do
    expect(@il).to be_a(InvisibleLogger)
  end

  it 'logs static log message with a stencil given level' do
    result = @il.l(binding, :static_string)

    expect(result).to be_truthy
    expect(read_output(@log_output)).to eq(info_log_prefix + "#{static_string_template}\n")
  end

  it 'uses binding context to fill templates with values' do
    @place  = 'Los Angeles'
    message = format(
      binding_template,
      name: name, HOBBIE: HOBBIE, date: Time.now, :@place => @place
    ).split("|\n").join(' ')

    @il.l(binding, :template_string)

    expect(read_output(@log_output)).to eq(warning_log_prefix + "#{message}\n")
  end

  it 'glues multiline messages by "|\n" pattern' do
    @il.l(binding, :template_string)

    expect(read_output(@log_output).split("\n").count).to eq(2)
  end

  it 'outputs multiline messages' do
    @il.l(binding, :multiline_template_string)

    expect(read_output(@log_output).split("\n").count).to eq(4)
  end

  it 'ignores wrong logging levels (Logger methods)' do
    result = @il.l(binding, :unexisted_level)

    expect(result).to be_falsy
    expect(read_output(@log_output)).to be_empty
  end

  it 'allows to aggregate log messages (without being interrupted)' do
    @place = 'Los Angeles'

    message = format(
      binding_template,
      name: name, HOBBIE: HOBBIE, date: Time.now, :@place => @place
    ).split("\n").join(' ').tr('|', '').strip

    aggregation_result = @il.l(binding, :aggregation_example_1, aggregate: true)

    log_result = @il.l(binding, :static_string)

    @il.l(binding, :aggregation_example_2, aggregate: true)
    expect(@il.level).to eq(:info)

    @il.l(binding, :aggregation_example_3, aggregate: true)
    @il.l(binding, :aggregation_example_4, aggregate: true)

    flushing_result = @il.f!

    # Usual logs work and don't iterrupt the aggreagtion
    expect(log_result).to be_truthy

    # Aggregation doesn't log enything
    expect(aggregation_result).to be_falsy

    # Flushing reports successfull log
    expect(flushing_result).to be_truthy

    # Buffer gets leared after successfull flushing
    expect(@il.buffer).to be_empty

    # the level of the last stencil is the level of the aggregated log
    expect(@il.level).to eq(:error)

    expect(read_output(@log_output)).to eq(
      info_log_prefix + "#{static_string_template}\n" +
      error_log_prefix + " #{message}\n"
    )
  end

  it 'allows to clear aggreagtor without logging' do
    @il.l(binding, :aggregation_example_1, aggregate: true)
    @il.l(binding, :aggregation_example_2, aggregate: true)
    @il.l(binding, :aggregation_example_3, aggregate: true)

    @il.f!(true)

    expect(read_output(@log_output)).to be_empty
    expect(@il.aggregator).to be_empty
  end

  it 'allows to debug a particular log' do
    @il.l(binding, :static_string, debug: true)
    expect(read_output(@log_output)).to eq(info_log_prefix + "▶️  static_string :: #{static_string_template}\n")
  end

  it 'allows to debug all the log messages' do
    allow(ENV).to receive(:[]).with('INV_LOGGER_DEBUG').and_return('true')

    @il.l(binding, :static_string)
    @il.l(binding, :static_string)

    expect(read_output(@log_output)).to eq((info_log_prefix + "▶️  static_string :: #{static_string_template}\n") * 2)
  end

  it 'allows to change the debug marker' do
    allow(ENV).to receive(:[]).with('INV_LOGGER_DEBUG_MARKER').and_return('🎳  ')

    @il = InvisibleLogger.new(logger: @logger, log_stencil: log_stencil)

    @il.l(binding, :static_string, debug: true)

    expect(read_output(@log_output)).to eq(info_log_prefix + "🎳  static_string :: #{static_string_template}\n")
  end

  it 'allows exceptions when debugging' do
    expect(@il.l(binding, :error_string, debug: false)).to be_nil
    expect { @il.l(binding, :error_string, debug: true) }.to raise_error(KeyError)
  end

  it 'ignores unexisted stencil names' do
    result = @il.l(binding, :unexisted_stencil)

    expect(result).to be_falsy
    expect(read_output(@log_output)).to be_empty
  end
end
