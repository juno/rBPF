require "test_helper"

class OpcodeTest < Minitest::Test
  def test_matches_linux_filter_h_encoding
    assert_equal 0x28, Op::LD | Op::H | Op::ABS   # ldh [k]
    assert_equal 0x30, Op::LD | Op::B | Op::ABS   # ldb [k]
    assert_equal 0x48, Op::LD | Op::H | Op::IND   # ldh [x+k]
    assert_equal 0x80, Op::LD | Op::W | Op::LEN   # ld #len
    assert_equal 0xb1, Op::LDX | Op::B | Op::MSH  # ldxb 4*([k]&0xf)
    assert_equal 0x15, Op::JMP | Op::JEQ | Op::K  # jeq #k
    assert_equal 0x45, Op::JMP | Op::JSET | Op::K # jset #k
    assert_equal 0x05, Op::JMP | Op::JA           # ja
    assert_equal 0x0c, Op::ALU | Op::ADD | Op::X  # add x
    assert_equal 0x84, Op::ALU | Op::NEG          # neg
    assert_equal 0x94, Op::ALU | Op::MOD          # mod
    assert_equal 0x06, Op::RET | Op::RET_K        # ret #k
    assert_equal 0x16, Op::RET | Op::RET_X        # ret x
    assert_equal 0x1e, Op::RET | Op::RET_A        # ret a
    assert_equal 0x07, Op::MISC | Op::TAX         # tax
    assert_equal 0x87, Op::MISC | Op::TXA         # txa
  end

  def test_insn_defaults_to_zero
    insn = Rbpf::Insn.new(0x06)
    assert_equal [0x06, 0, 0, 0], [insn.code, insn.jt, insn.jf, insn.k]
  end
end
