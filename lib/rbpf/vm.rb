module Rbpf
  class VM
    MASK = 0xFFFFFFFF
    SIZES = { Op::W => ["N", 4], Op::H => ["n", 2], Op::B => ["C", 1] }.freeze

    def initialize(prog, packet)
      @prog = prog
      @pkt = packet.b
      @a = 0
      @x = 0
      @m = Array.new(Verifier::MEMWORDS, 0)
    end

    def run
      pc = 0
      catch(:ret) do
        loop do
          insn = @prog[pc]
          pc += 1
          case insn.code & 0x07
          when Op::LD, Op::LDX then load(insn)
          when Op::ST then @m[insn.k] = @a
          when Op::STX then @m[insn.k] = @x
          when Op::ALU then alu(insn)
          when Op::JMP then pc = jump(insn, pc)
          when Op::RET then throw :ret, ret_value(insn)
          when Op::MISC then insn.code == (Op::MISC | Op::TAX) ? @x = @a : @a = @x
          end
        end
      end
    end

    private

    def load(insn)
      size = insn.code & 0x18
      value = case insn.code & 0xe0
              when Op::IMM then insn.k
              when Op::LEN then @pkt.bytesize
              when Op::MEM then @m[insn.k]
              when Op::ABS then read(insn.k, size)
              when Op::IND then read((@x + insn.k) & MASK, size)
              when Op::MSH then 4 * (read(insn.k, Op::B) & 0xf)
              end
      (insn.code & 0x07) == Op::LD ? @a = value : @x = value
    end

    # 範囲外は例外にせず、プログラム全体を返り値0で終了する(カーネル準拠)
    def read(offset, size)
      fmt, len = SIZES.fetch(size)
      throw :ret, 0 if offset + len > @pkt.bytesize
      @pkt.byteslice(offset, len).unpack1(fmt)
    end

    def alu(insn)
      src = (insn.code & Op::X) == Op::X ? @x : insn.k
      result = case insn.code & 0xf0
               when Op::ADD then @a + src
               when Op::SUB then @a - src
               when Op::MUL then @a * src
               when Op::DIV then (throw :ret, 0 if src == 0; @a / src)
               when Op::MOD then (throw :ret, 0 if src == 0; @a % src)
               when Op::OR then @a | src
               when Op::AND then @a & src
               when Op::XOR then @a ^ src
               when Op::LSH then src >= 32 ? 0 : @a << src
               when Op::RSH then src >= 32 ? 0 : @a >> src
               when Op::NEG then -@a
               end
      @a = result & MASK
    end

    def jump(insn, pc)
      op = insn.code & 0xf0
      return pc + insn.k if op == Op::JA

      src = (insn.code & Op::X) == Op::X ? @x : insn.k
      taken = case op
              when Op::JEQ then @a == src
              when Op::JGT then @a > src
              when Op::JGE then @a >= src
              when Op::JSET then (@a & src) != 0
              end
      pc + (taken ? insn.jt : insn.jf)
    end

    def ret_value(insn)
      insn.code & 0x18 == Op::RET_K ? insn.k : @a
    end
  end
end
