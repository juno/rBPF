require "test_helper"

class AluTest < Minitest::Test
  # A = a; A = A <op> k
  def alu_k(op, a, k)
    Rbpf.run([ins(Op::LD | Op::IMM, a), ins(Op::ALU | op | Op::K, k), ret_a], "")
  end

  # A = a; X = x; A = A <op> X
  def alu_x(op, a, x)
    Rbpf.run([ins(Op::LD | Op::IMM, a), ins(Op::LDX | Op::W | Op::IMM, x),
              ins(Op::ALU | op | Op::X), ret_a], "")
  end

  def test_add
    assert_equal 3, alu_k(Op::ADD, 1, 2)
    assert_equal 3, alu_x(Op::ADD, 1, 2)
    assert_equal 0, alu_k(Op::ADD, 0xFFFFFFFF, 1)
  end

  def test_sub_wraps_to_32bit
    assert_equal 1, alu_k(Op::SUB, 3, 2)
    assert_equal 0xFFFFFFFF, alu_k(Op::SUB, 1, 2)
    assert_equal 0xFFFFFFFF, alu_x(Op::SUB, 1, 2)
  end

  def test_mul_wraps_to_32bit
    assert_equal 6, alu_k(Op::MUL, 2, 3)
    assert_equal 0, alu_k(Op::MUL, 0x10000, 0x10000)
  end

  def test_div_and_mod
    assert_equal 3, alu_k(Op::DIV, 7, 2)
    assert_equal 1, alu_k(Op::MOD, 7, 2)
    assert_equal 3, alu_x(Op::DIV, 7, 2)
    assert_equal 1, alu_x(Op::MOD, 7, 2)
  end

  def test_div_and_mod_by_zero_x_return_zero
    [Op::DIV, Op::MOD].each do |op|
      prog = [ins(Op::LD | Op::IMM, 10), ins(Op::LDX | Op::W | Op::IMM, 0),
              ins(Op::ALU | op | Op::X), ret_k(99)]
      assert_equal 0, Rbpf.run(prog, "")
    end
  end

  def test_bitwise
    assert_equal 0x30, alu_k(Op::AND, 0xf0, 0x3c)
    assert_equal 0xfc, alu_k(Op::OR, 0xf0, 0x3c)
    assert_equal 0xf0, alu_k(Op::XOR, 0xff, 0x0f)
    assert_equal 0x30, alu_x(Op::AND, 0xf0, 0x3c)
  end

  def test_shifts
    assert_equal 16, alu_k(Op::LSH, 1, 4)
    assert_equal 1, alu_k(Op::RSH, 16, 4)
    assert_equal 16, alu_x(Op::LSH, 1, 4)
    assert_equal 1, alu_x(Op::RSH, 16, 4)
  end

  def test_lsh_truncates_to_32bit
    assert_equal 0, alu_k(Op::LSH, 0x80000000, 1)
    assert_equal 0xFFFFFFFE, alu_k(Op::LSH, 0xFFFFFFFF, 1)
  end

  # Linux: X 版は実行時に X & 31 でマスクする(K 版の k >= 32 は verifier が拒否)
  def test_shift_by_x_is_masked_to_5_bits
    assert_equal 2, alu_x(Op::LSH, 1, 33)
    assert_equal 1, alu_x(Op::LSH, 1, 32)
    assert_equal 0xFFFFFFFF, alu_x(Op::RSH, 0xFFFFFFFF, 32)
    assert_equal 0x7FFFFFFF, alu_x(Op::RSH, 0xFFFFFFFF, 33)
  end

  def test_neg
    assert_equal 0xFFFFFFFF, Rbpf.run([ins(Op::LD | Op::IMM, 1), ins(Op::ALU | Op::NEG), ret_a], "")
    assert_equal 0, Rbpf.run([ins(Op::LD | Op::IMM, 0), ins(Op::ALU | Op::NEG), ret_a], "")
  end
end
