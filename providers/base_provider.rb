# frozen_string_literal: true

module BaseProvider
  def generate_content(_history, _tools, system_prompt: nil)
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def parse_response(_response)
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def tool_format
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end
end
