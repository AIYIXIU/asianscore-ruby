# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module AsianscoreQuant
  # Zero-dependency sports quantitative modeling primitives and live summary client
  # for AsianScore (https://asianscore.com/).
  module Models
    extend self

    DEFAULT_SUMMARY_URL = "https://asianscore.com/api/widget/summary"

    # Remove bookmaker overround proportionally from decimal odds.
    #
    # @param odds [Array<Numeric>] Decimal odds (> 1.0) for all mutually exclusive outcomes.
    # @return [Array<Float>] Fair probabilities summing to 1.0.
    def devig_multiplicative(odds)
      implied = extract_implied_probs(odds)
      total = implied.sum
      implied.map { |p| p / total }
    end

    # Remove bookmaker overround using the power method: solves sum((1/o)^k) = 1.0 via binary search.
    #
    # @param odds [Array<Numeric>] Decimal odds (> 1.0) for all mutually exclusive outcomes.
    # @param tol [Float] Convergence tolerance for the root solver.
    # @param max_iter [Integer] Maximum binary search iterations.
    # @return [Array<Float>] Fair probabilities summing to 1.0.
    def devig_power(odds, tol: 1e-12, max_iter: 200)
      implied = extract_implied_probs(odds)
      initial_sum = implied.sum
      return implied.map { |p| p / initial_sum } if (initial_sum - 1.0).abs <= tol

      if initial_sum > 1.0
        low = 1.0
        high = 2.0
        high *= 2.0 while implied.sum { |p| p**high } > 1.0 && high < 1_000_000.0
      else
        low = 0.0
        high = 1.0
      end

      max_iter.times do
        mid = 0.5 * (low + high)
        val = implied.sum { |p| p**mid }
        if (val - 1.0).abs <= tol || (high - low) <= tol
          low = high = mid
          break
        elsif val > 1.0
          low = mid
        else
          high = mid
        end
      end

      k = 0.5 * (low + high)
      raw = implied.map { |p| p**k }
      total = raw.sum
      raw.map { |p| p / total }
    end

    # Compute fractional Kelly criterion stake sizing.
    #
    # @param prob [Numeric] Estimated fair probability in (0, 1).
    # @param decimal_odds [Numeric] Available decimal odds (> 1.0).
    # @param fraction [Numeric] Kelly multiplier (default 0.25 for quarter-Kelly).
    # @return [Float] Recommended bankroll stake fraction (>= 0.0).
    def kelly_fraction(prob, decimal_odds, fraction: 0.25)
      p = prob.to_f
      odds = decimal_odds.to_f
      scale = fraction.to_f

      raise ArgumentError, "fraction must be >= 0.0" if scale.negative?
      return 0.0 if p <= 0.0 || p >= 1.0 || odds <= 1.0 || scale.zero?

      b = odds - 1.0
      full_kelly = (b * p - (1.0 - p)) / b
      return 0.0 if full_kelly <= 0.0

      full_kelly * scale
    end

    # Compute Dixon-Coles low-score adjusted bivariate Poisson match probabilities.
    #
    # @param lambda_home [Numeric] Expected goals for the home team (>= 0.0).
    # @param lambda_away [Numeric] Expected goals for the away team (>= 0.0).
    # @param rho [Numeric] Low-score correlation adjustment parameter (default -0.08).
    # @param max_goals [Integer] Goal truncation ceiling per side (default 15).
    # @return [Hash{Symbol => Float}] :home_win, :draw, :away_win, :over_2_5, and :btts probabilities.
    def dixon_coles_probs(lambda_home, lambda_away, rho: -0.08, max_goals: 15)
      lh = lambda_home.to_f
      la = lambda_away.to_f
      r = rho.to_f

      raise ArgumentError, "expected goals must be >= 0.0" if lh.negative? || la.negative?
      raise ArgumentError, "max_goals must be >= 1" if max_goals < 1

      home_pmf = poisson_distribution(lh, max_goals)
      away_pmf = poisson_distribution(la, max_goals)

      home_win = 0.0
      draw = 0.0
      away_win = 0.0
      over_2_5 = 0.0
      btts = 0.0
      total = 0.0

      (0..max_goals).each do |h|
        ph = home_pmf[h]
        (0..max_goals).each do |a|
          tau = dixon_coles_tau(h, a, lh, la, r)
          prob = ph * away_pmf[a] * tau
          prob = 0.0 if prob.negative?

          total += prob
          if h > a
            home_win += prob
          elsif h == a
            draw += prob
          else
            away_win += prob
          end

          over_2_5 += prob if (h + a) > 2
          btts += prob if h.positive? && a.positive?
        end
      end

      raise ArgumentError, "degenerate probability grid" if total <= 0.0

      {
        home_win: home_win / total,
        draw: draw / total,
        away_win: away_win / total,
        over_2_5: over_2_5 / total,
        btts: btts / total
      }
    end

    # Compute the multi-class Brier score (mean squared error across outcome probabilities).
    #
    # @param probs [Array<Numeric>] Predicted probability vector.
    # @param actual_index [Integer] Zero-based index of the realized outcome.
    # @return [Float] Multi-class Brier score in [0.0, 2.0 / n].
    def brier_score(probs, actual_index)
      raise ArgumentError, "probs must be a non-empty Array" unless probs.is_a?(Array) && !probs.empty?
      unless actual_index.is_a?(Integer) && actual_index >= 0 && actual_index < probs.length
        raise ArgumentError, "actual_index out of range"
      end

      squared_error = 0.0
      probs.each_with_index do |prob, idx|
        target = idx == actual_index ? 1.0 : 0.0
        diff = prob.to_f - target
        squared_error += diff * diff
      end
      squared_error / probs.length.to_f
    end

    # Fetch live fixtures and SHA-256 verifiable ledger summary from AsianScore.
    #
    # @param url [String] Summary endpoint URL.
    # @param timeout [Numeric] HTTP open and read timeout in seconds.
    # @return [Hash] Parsed JSON payload.
    def fetch_live_summary(url: DEFAULT_SUMMARY_URL, timeout: 15)
      current_url = url
      3.times do
        uri = URI.parse(current_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.open_timeout = timeout
        http.read_timeout = timeout

        request = Net::HTTP::Get.new(uri.request_uri)
        request["User-Agent"] = "asianscore_quant/#{AsianscoreQuant::VERSION} (+https://asianscore.com/)"
        request["Accept"] = "application/json"

        response = http.request(request)
        if response.is_a?(Net::HTTPRedirection) && response["location"]
          current_url = URI.join(current_url, response["location"]).to_s
          next
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise "AsianScore API returned HTTP #{response.code} #{response.message}"
        end

        return JSON.parse(response.body)
      end

      raise "Too many HTTP redirects while fetching #{url}"
    end

    private

    def extract_implied_probs(odds)
      raise ArgumentError, "odds must be a non-empty Array" unless odds.is_a?(Array) && !odds.empty?

      odds.map do |o|
        val = o.to_f
        raise ArgumentError, "all decimal odds must be > 1.0" unless o.is_a?(Numeric) && val > 1.0

        1.0 / val
      end
    end

    def poisson_distribution(lambda, max_goals)
      pmf = Array.new(max_goals + 1, 0.0)
      if lambda.zero?
        pmf[0] = 1.0
        return pmf
      end

      pmf[0] = Math.exp(-lambda)
      (1..max_goals).each do |k|
        pmf[k] = pmf[k - 1] * lambda / k.to_f
      end
      pmf
    end

    def dixon_coles_tau(home_goals, away_goals, lambda_home, lambda_away, rho)
      if home_goals.zero? && away_goals.zero?
        1.0 - lambda_home * lambda_away * rho
      elsif home_goals.zero? && away_goals == 1
        1.0 + lambda_home * rho
      elsif home_goals == 1 && away_goals.zero?
        1.0 + lambda_away * rho
      elsif home_goals == 1 && away_goals == 1
        1.0 - rho
      else
        1.0
      end
    end
  end
end
