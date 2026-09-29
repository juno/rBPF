require "test_helper"

class JmpTest < Minitest::Test
  # A = a; if (A <op> k) ret 1 else ret 0
  def cond_k(op, a, k)
    Rbpf.run([ins(Op::LD | Op::IMM, a), ins(Op::JMP | op | Op::K, k, 0, 1),
              ret_k(1), ret_k(0)], "")
  end

  # A = a; X = x; if (A <op> X) ret 1 else ret 0
  def cond_x(op, a, x)
    Rbpf.run([ins(Op::LD | Op::IMM, a), ins(Op::LDX | Op::W | Op::IMM, x),
              ins(Op::JMP | op | Op::X, 0, 0, 1), ret_k(1), ret_k(0)], "")
  end

  def test_ja_skips_k_instructions
    assert_equal 2, Rbpf.run([ins(Op::JMP | Op::JA, 1), ret_k(1), ret_k(2)], "")
  end

  def test_jeq
    assert_equal 1, cond_k(Op::JEQ, 5, 5)
    assert_equal 0, cond_k(Op::JEQ, 5, 6)
    assert_equal 1, cond_x(Op::JEQ, 5, 5)
    assert_equal 0, cond_x(Op::JEQ, 5, 6)
  end

  def test_jgt
    assert_equal 1, cond_k(Op::JGT, 6, 5)
    assert_equal 0, cond_k(Op::JGT, 5, 5)
    assert_equal 1, cond_x(Op::JGT, 6, 5)
  end

  def test_jge
    assert_equal 1, cond_k(Op::JGE, 5, 5)
    assert_equal 0, cond_k(Op::JGE, 4, 5)
    assert_equal 1, cond_x(Op::JGE, 5, 5)
  end

  def test_jset
    assert_equal 1, cond_k(Op::JSET, 0b101, 0b100)
    assert_equal 0, cond_k(Op::JSET, 0b101, 0b010)
    assert_equal 1, cond_x(Op::JSET, 0b101, 0b100)
  end

  def test_comparisons_are_unsigned
    assert_equal 1, cond_k(Op::JGT, 0xFFFFFFFF, 1)
    assert_equal 0, cond_k(Op::JGT, 1, 0xFFFFFFFF)
    assert_equal 1, cond_k(Op::JGE, 0x80000000, 1)
  end

  def test_jt_can_skip_forward
    prog = [ins(Op::LD | Op::IMM, 1), ins(Op::JMP | Op::JEQ | Op::K, 1, 1, 0),
            ret_k(0), ret_k(1)]
    assert_equal 1, Rbpf.run(prog, "")
  end
end
