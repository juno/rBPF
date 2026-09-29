require "test_helper"

class VmTest < Minitest::Test
  PKT = "\x01\x02\x03\x04\x05".b

  def run_bpf(prog, pkt = "")
    Rbpf.run(prog, pkt)
  end

  def test_ret_k
    assert_equal 7, run_bpf([ret_k(7)])
  end

  def test_accepts_array_form
    assert_equal 7, run_bpf([[0x06, 0, 0, 7]])
  end

  def test_run_rejects_invalid_program
    assert_raises(Rbpf::InvalidProgram) { run_bpf([]) }
  end

  def test_ld_imm_and_ret_a
    assert_equal 5, run_bpf([ins(Op::LD | Op::IMM, 5), ret_a])
  end

  def test_ldx_imm_and_ret_x
    assert_equal 9, run_bpf([ins(Op::LDX | Op::W | Op::IMM, 9), ret_x])
  end

  def test_ld_abs_is_big_endian
    assert_equal 0x01020304, run_bpf([ins(Op::LD | Op::W | Op::ABS, 0), ret_a], PKT)
    assert_equal 0x0203, run_bpf([ins(Op::LD | Op::H | Op::ABS, 1), ret_a], PKT)
    assert_equal 5, run_bpf([ins(Op::LD | Op::B | Op::ABS, 4), ret_a], PKT)
  end

  def test_ld_ind_adds_x
    prog = [ins(Op::LDX | Op::W | Op::IMM, 2), ins(Op::LD | Op::B | Op::IND, 1), ret_a]
    assert_equal 4, run_bpf(prog, PKT)
  end

  def test_ld_ind_offset_wraps_at_32bit
    prog = [ins(Op::LDX | Op::W | Op::IMM, 0xFFFFFFFF), ins(Op::LD | Op::B | Op::IND, 2), ret_a]
    assert_equal 2, run_bpf(prog, PKT)  # (0xFFFFFFFF + 2) & 0xFFFFFFFF = 1 -> PKT[1]
  end

  def test_out_of_range_read_returns_zero
    assert_equal 0, run_bpf([ins(Op::LD | Op::W | Op::ABS, 2), ret_k(99)], "\x01\x02\x03\x04".b)
    assert_equal 0, run_bpf([ins(Op::LD | Op::B | Op::ABS, 0), ret_k(99)], "")
  end

  def test_huge_offset_returns_zero
    assert_equal 0, run_bpf([ins(Op::LD | Op::B | Op::ABS, 0xFFFFFFFF), ret_k(99)], PKT)
  end

  def test_ld_len_and_ldx_len
    assert_equal 5, run_bpf([ins(Op::LD | Op::W | Op::LEN), ret_a], PKT)
    assert_equal 5, run_bpf([ins(Op::LDX | Op::W | Op::LEN), ret_x], PKT)
    assert_equal 0, run_bpf([ins(Op::LD | Op::W | Op::LEN), ret_a], "")
  end

  def test_ldx_msh
    assert_equal 20, run_bpf([ins(Op::LDX | Op::B | Op::MSH, 0), ret_x], "\x45".b)
  end

  def test_st_and_ld_mem
    prog = [ins(Op::LD | Op::IMM, 42), ins(Op::ST, 3), ins(Op::LD | Op::IMM, 0),
            ins(Op::LD | Op::W | Op::MEM, 3), ret_a]
    assert_equal 42, run_bpf(prog)
  end

  def test_stx_and_ldx_mem
    prog = [ins(Op::LDX | Op::W | Op::IMM, 7), ins(Op::STX, 1), ins(Op::LDX | Op::W | Op::IMM, 0),
            ins(Op::LDX | Op::W | Op::MEM, 1), ret_x]
    assert_equal 7, run_bpf(prog)
  end

  def test_tax_and_txa
    assert_equal 3, run_bpf([ins(Op::LD | Op::IMM, 3), ins(Op::MISC | Op::TAX), ret_x])
    assert_equal 4, run_bpf([ins(Op::LDX | Op::W | Op::IMM, 4), ins(Op::MISC | Op::TXA), ret_a])
  end
end
