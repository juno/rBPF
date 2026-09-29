require "test_helper"

class ProgramTest < Minitest::Test
  def test_compile_then_run_matches_rbpf_run
    prog = [ins(Op::LD | Op::W | Op::LEN), ret_a]
    program = Rbpf.compile(prog)
    assert_equal Rbpf.run(prog, "abc"), program.run("abc")
  end

  def test_program_is_reusable_across_packets
    program = Rbpf.compile([ins(Op::LD | Op::W | Op::LEN), ret_a])
    assert_equal [3, 0, 5], [program.run("abc"), program.run(""), program.run("abcde")]
  end

  def test_compile_verifies_immediately
    assert_raises(Rbpf::InvalidProgram) { Rbpf.compile([]) }
  end

  def test_compiled_program_is_a_snapshot_of_the_source_array
    prog = [ret_k(7)]
    program = Rbpf.compile(prog)
    prog.clear
    assert_equal 7, program.run("")
  end

  def test_compiled_program_ignores_later_mutation_of_insns
    insn = ret_k(7)
    program = Rbpf.compile([insn])
    insn.k = -1  # verifier を通った後に不正な値へ書き換えても影響しない
    assert_equal 7, program.run("")
  end
end
