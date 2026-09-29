module Rbpf
  class InvalidProgram < StandardError; end

  module Verifier
    MAX_INSNS = 4096
    MEMWORDS = 16

    LD_CODES = [Op::W, Op::H, Op::B].product([Op::ABS, Op::IND]).map { |s, m| Op::LD | s | m } +
               [Op::LD | Op::W | Op::IMM, Op::LD | Op::W | Op::LEN, Op::LD | Op::W | Op::MEM]
    LDX_CODES = [Op::LDX | Op::W | Op::IMM, Op::LDX | Op::W | Op::LEN,
                 Op::LDX | Op::W | Op::MEM, Op::LDX | Op::B | Op::MSH]
    ALU_CODES = [Op::ADD, Op::SUB, Op::MUL, Op::DIV, Op::OR, Op::AND,
                 Op::LSH, Op::RSH, Op::MOD, Op::XOR]
                .product([Op::K, Op::X]).map { |o, s| Op::ALU | o | s } + [Op::ALU | Op::NEG]
    JMP_COND_CODES = [Op::JEQ, Op::JGT, Op::JGE, Op::JSET]
                     .product([Op::K, Op::X]).map { |o, s| Op::JMP | o | s }
    RET_CODES = [Op::RET | Op::RET_K, Op::RET | Op::RET_X, Op::RET | Op::RET_A]
    MISC_CODES = [Op::MISC | Op::TAX, Op::MISC | Op::TXA]

    def self.verify!(prog)
      bad(nil, "empty program") if prog.empty?
      bad(nil, "program too long") if prog.size > MAX_INSNS
      prog.each_with_index { |insn, pc| check(insn, pc, prog.size) }
      bad(prog.size - 1, "last instruction must be ret") unless prog.last.code & 0x07 == Op::RET
      nil
    end

    def self.check(insn, pc, n)
      code = insn.code
      case code
      when Op::LD | Op::W | Op::MEM, Op::LDX | Op::W | Op::MEM, Op::ST, Op::STX
        bad(pc, "scratch index out of range") unless insn.k < MEMWORDS
      when Op::ALU | Op::DIV | Op::K, Op::ALU | Op::MOD | Op::K
        bad(pc, "division by zero") if insn.k == 0
      when Op::JMP | Op::JA
        bad(pc, "jump out of range") unless pc + 1 + insn.k < n
      when *JMP_COND_CODES
        bad(pc, "jump out of range") unless pc + 1 + insn.jt < n && pc + 1 + insn.jf < n
      when *(LD_CODES + LDX_CODES + ALU_CODES + RET_CODES + MISC_CODES)
        nil
      else
        bad(pc, "unknown opcode 0x#{code.to_s(16)}")
      end
    end

    def self.bad(pc, msg)
      raise InvalidProgram, pc ? "insn #{pc}: #{msg}" : msg
    end
  end
end
