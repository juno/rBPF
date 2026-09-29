require_relative "rbpf/opcode"
require_relative "rbpf/verifier"
require_relative "rbpf/vm"

module Rbpf
  Insn = Struct.new(:code, :jt, :jf, :k) do
    def initialize(code, jt = 0, jf = 0, k = 0)
      super
    end
  end

  def self.normalize(prog)
    prog.map { |insn| insn.is_a?(Insn) ? insn : Insn.new(*insn) }
  end

  def self.verify!(prog)
    Verifier.verify!(normalize(prog))
  end

  def self.run(prog, packet)
    prog = normalize(prog)
    Verifier.verify!(prog)
    VM.new(prog, packet).run
  end
end
