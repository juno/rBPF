require "test_helper"

class VerifierTest < Minitest::Test
  def invalid(prog)
    assert_raises(Rbpf::InvalidProgram) { Rbpf.verify!(prog) }
  end

  def test_accepts_minimal_program
    assert_nil Rbpf.verify!([ret_k(0)])
  end

  def test_accepts_array_form
    assert_nil Rbpf.verify!([[0x06, 0, 0, 0]])
  end

  def test_rejects_empty_program
    invalid([])
  end

  def test_program_length_limit_is_4096
    assert_nil Rbpf.verify!(Array.new(4096) { ret_k(0) })
    invalid(Array.new(4097) { ret_k(0) })
  end

  def test_rejects_unknown_opcode
    invalid([ins(0xff), ret_k(0)])
  end

  def test_rejects_invalid_size_or_mode_combination
    invalid([ins(Op::LD | Op::H | Op::IMM, 1), ret_a])   # imm は W のみ
    invalid([ins(Op::LD | 0x18 | Op::ABS, 0), ret_a])    # 不正なsize
    invalid([ins(Op::LDX | Op::W | Op::MSH, 0), ret_a])  # msh は B のみ
  end

  def test_rejects_when_last_is_not_ret
    invalid([ins(Op::LD | Op::IMM, 1)])
  end

  def test_rejects_ja_out_of_range
    assert_nil Rbpf.verify!([ins(Op::JMP | Op::JA, 0), ret_k(0)])
    invalid([ins(Op::JMP | Op::JA, 1), ret_k(0)])
  end

  def test_rejects_ja_with_huge_k
    invalid([ins(Op::JMP | Op::JA, 0xFFFFFFFF), ret_k(0)])
  end

  def test_rejects_conditional_jump_out_of_range
    invalid([ins(Op::JMP | Op::JEQ | Op::K, 0, 5, 0), ret_k(0)])  # jt
    invalid([ins(Op::JMP | Op::JEQ | Op::K, 0, 0, 5), ret_k(0)])  # jf
    assert_nil Rbpf.verify!([ins(Op::JMP | Op::JEQ | Op::K, 0, 1, 0), ret_k(0), ret_k(1)])
  end

  def test_rejects_division_by_constant_zero
    invalid([ins(Op::ALU | Op::DIV | Op::K, 0), ret_a])
    invalid([ins(Op::ALU | Op::MOD | Op::K, 0), ret_a])
    assert_nil Rbpf.verify!([ins(Op::ALU | Op::DIV | Op::X), ret_a])  # X は実行時に判定
  end

  def test_rejects_scratch_index_out_of_range
    assert_nil Rbpf.verify!([ins(Op::ST, 15), ret_k(0)])
    invalid([ins(Op::ST, 16), ret_k(0)])
    invalid([ins(Op::STX, 16), ret_k(0)])
    invalid([ins(Op::LD | Op::W | Op::MEM, 16), ret_a])
    invalid([ins(Op::LDX | Op::W | Op::MEM, 16), ret_a])
  end

  def test_rejects_ret_with_invalid_source
    invalid([ins(Op::RET | 0x08)])
  end

  def test_rejects_ret_x_which_linux_does_not_have
    invalid([ins(Op::RET | 0x08)])  # 0x0e
    invalid([ins(Op::RET | 0x18)])  # 0x1e
    assert_nil Rbpf.verify!([ins(Op::RET | Op::RET_A)])
  end

  def test_rejects_negative_jump_offsets
    invalid([ins(Op::JMP | Op::JEQ | Op::K, 0, -1, -1), ret_k(0)])
    invalid([ins(Op::JMP | Op::JA, -1), ret_k(0)])
  end

  def test_rejects_negative_k
    invalid([ins(Op::LD | Op::B | Op::ABS, -1), ret_a])
    invalid([ins(Op::ST, -1), ret_k(0)])
    invalid([ins(Op::LD | Op::W | Op::MEM, -17), ret_a])
  end

  def test_rejects_out_of_range_fields
    invalid([ins(Op::RET | Op::RET_K, 2**32)])                       # k > u32
    invalid([ins(Op::LD | Op::IMM, 2**33), ret_a])
    invalid([ins(Op::JMP | Op::JEQ | Op::K, 0, 256, 0), ret_k(0)])   # jt > u8
    invalid([ins(Op::JMP | Op::JEQ | Op::K, 0, 0, 256), ret_k(0)])   # jf > u8
    invalid([ins(0x10000), ret_k(0)])                                # code > u16
    assert_nil Rbpf.verify!([ins(Op::RET | Op::RET_K, 0xFFFFFFFF)])
  end

  def test_rejects_non_integer_fields
    invalid([ins(Op::ST, nil), ret_k(0)])
    invalid([ins(nil), ret_k(0)])
    invalid([ins(Op::RET | Op::RET_K, 1.5)])
  end

  def test_rejects_constant_shift_of_32_or_more
    [Op::LSH, Op::RSH].each do |op|
      assert_nil Rbpf.verify!([ins(Op::ALU | op | Op::K, 31), ret_a])
      invalid([ins(Op::ALU | op | Op::K, 32), ret_a])
    end
    assert_nil Rbpf.verify!([ins(Op::ALU | Op::LSH | Op::X), ret_a])  # X は実行時にマスク
  end

  def test_rejects_load_from_uninitialized_scratch
    invalid([ins(Op::LD | Op::W | Op::MEM, 0), ret_a])
    invalid([ins(Op::LDX | Op::W | Op::MEM, 3), ret_a])
    invalid([ins(Op::ST, 1), ins(Op::LD | Op::W | Op::MEM, 0), ret_a])  # 別のセル
  end

  def test_accepts_load_after_store
    assert_nil Rbpf.verify!([ins(Op::ST, 0), ins(Op::LD | Op::W | Op::MEM, 0), ret_a])
    assert_nil Rbpf.verify!([ins(Op::STX, 2), ins(Op::LDX | Op::W | Op::MEM, 2), ret_a])
  end

  def test_rejects_load_when_only_one_branch_stored
    prog = [ins(Op::JMP | Op::JEQ | Op::K, 0, 0, 1),  # 0: true -> 1, false -> 2
            ins(Op::ST, 0),                            # 1
            ins(Op::LD | Op::W | Op::MEM, 0),          # 2: false 経路は未書き込み
            ret_a]
    invalid(prog)
  end

  def test_accepts_load_when_all_branches_stored
    prog = [ins(Op::JMP | Op::JEQ | Op::K, 0, 0, 2),  # 0: true -> 1, false -> 3
            ins(Op::ST, 0),                            # 1
            ins(Op::JMP | Op::JA, 1),                  # 2: -> 4
            ins(Op::ST, 0),                            # 3
            ins(Op::LD | Op::W | Op::MEM, 0),          # 4
            ret_a]
    assert_nil Rbpf.verify!(prog)
  end
end
