# frozen_string_literal: true

module Jules
  class Result
    def self.ok(value)
      new(success: true, value: value)
    end

    def self.err(code:, message:, detail: nil)
      new(success: false, error: { code: code, message: message, detail: detail })
    end

    def initialize(success:, value: nil, error: nil)
      @ok = success
      @value = value
      @error = error
    end

    attr_reader :value

    def ok?
      @ok
    end

    def err?
      !@ok
    end

    def code
      @error && @error[:code]
    end

    def message
      @error && @error[:message]
    end

    def detail
      @error && @error[:detail]
    end

    def as_h
      if ok?
        { ok: true, value: @value }
      else
        { ok: false, error: { code: code, message: message, detail: detail } }
      end
    end
  end
end
