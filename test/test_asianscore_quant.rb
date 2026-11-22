# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "asianscore_quant"

begin
  require "minitest/autorun"
  TEST_BASE = Minitest::Test
rescue LoadError
  # Pure-stdlib fallback runner when minitest is unavailable
  class PureStdlibTest
    def self.inherited(subclass)
      (@subclasses ||= []) << subclass
    end

    def self.run_all!
      failures = 0
      tests = 0
      (@subclasses || []).each do |klass|
        instance = klass.new
        klass.instance_methods(false).grep(/^test_/).sort.each do |method_name|
          tests += 1
          instance.public_send(method_name)
        rescue StandardError => e
          failures += 1
          warn "FAIL #{klass}##{method_name}: #{e.message}"
        end
      end
      puts "#{tests} tests, #{failures} failures"
      exit(1) if failures.positive?
    end

    def assert(condition, msg = "Expected condition to be truthy")
      raise msg unless condition
    end

    def assert_in_delta(expected, actual, delta = 1e-6, msg = nil)
      diff = (expected - actual).abs
      raise(msg || "Expected #{actual} to be within #{delta} of #{expected}") if diff > delta
    end

    def assert_raises(error_class)
      yield
      raise "Expected #{error_class} to be raised"
    rescue error_class
      true
    end
  end

  at_exit { PureStdlibTest.run_all! }
  TEST_BASE = PureStdlibTest
end

class TestAsianscoreQuant < TEST_BASE
  def test_devig_multiplicative_sums_to_one
    probs = AsianscoreQuant.devig_multiplicative([1.90, 3.50, 4.20])
    assert_in_delta 1.0, probs.sum, 1e-12
    assert probs[0] > probs[1] && probs[1] > probs[2]
  end

  def test_devig_power_sums_to_one_and_handles_longshot_bias
    odds = [1.45, 4.60, 7.50]
    mult = AsianscoreQuant.devig_multiplicative(odds)
    power = AsianscoreQuant.devig_power(odds)

    assert_in_delta 1.0, power.sum, 1e-12
    # Power devigging assigns higher fair probability to the favorite than multiplicative
    assert power[0] > mult[0]
    assert power[2] < mult[2]
  end

  def test_devig_rejects_invalid_odds
    assert_raises(ArgumentError) { AsianscoreQuant.devig_multiplicative([]) }
    assert_raises(ArgumentError) { AsianscoreQuant.devig_power([1.0, 2.5]) }
  end

  def test_kelly_fraction
    # Fair prob 0.55 at even odds (2.0) -> full Kelly 0.10, quarter-Kelly 0.025
    assert_in_delta 0.025, AsianscoreQuant.kelly_fraction(0.55, 2.0), 1e-12
    assert_in_delta 0.10, AsianscoreQuant.kelly_fraction(0.55, 2.0, fraction: 1.0), 1e-12
    # Negative edge should return 0.0
    assert_in_delta 0.0, AsianscoreQuant.kelly_fraction(0.40, 2.0), 1e-12
  end

  def test_dixon_coles_probs
    res = AsianscoreQuant.dixon_coles_probs(1.65, 1.15, rho: -0.08)
    total_1x2 = res[:home_win] + res[:draw] + res[:away_win]

    assert_in_delta 1.0, total_1x2, 1e-12
    assert res[:home_win] > res[:away_win]
    assert res[:over_2_5] > 0.0 && res[:over_2_5] < 1.0
    assert res[:btts] > 0.0 && res[:btts] < 1.0
  end

  def test_brier_score
    assert_in_delta 0.0, AsianscoreQuant.brier_score([1.0, 0.0, 0.0], 0), 1e-12
    # ((0.7-1)^2 + 0.2^2 + 0.1^2) / 3 = 0.14 / 3
    assert_in_delta 0.14 / 3.0, AsianscoreQuant.brier_score([0.7, 0.2, 0.1], 0), 1e-12
  end
end
