module Rbpf
  # verify 済みの命令列。命令のコピーを凍結して持つので、検査後に元の配列や Insn が変わっても影響しない
  class Program
    def initialize(prog)
      @insns = Rbpf.normalize(prog).map { |insn| insn.dup.freeze }.freeze
      Verifier.verify!(@insns)
    end

    def run(packet)
      VM.new(@insns, packet).run
    end
  end
end
