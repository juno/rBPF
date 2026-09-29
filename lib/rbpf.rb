require_relative "rbpf/opcode"

module Rbpf
  Insn = Struct.new(:code, :jt, :jf, :k) do
    def initialize(code, jt = 0, jf = 0, k = 0)
      super
    end
  end
end
