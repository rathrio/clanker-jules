# frozen_string_literal: true

class Message
  # @param role [String] user or model
  # @param parts [Array]
  def initialize(role, parts)
    @role = role
    @parts = parts
  end

  def as_gemini
    { role: @role, parts: @parts }
  end
end
