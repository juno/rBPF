$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "minitest/autorun"
require "rbpf"

module TestHelper
  Op = Rbpf::Op

  def ins(code, k = 0, jt = 0, jf = 0)
    Rbpf::Insn.new(code, jt, jf, k)
  end

  def ret_k(k) = ins(Op::RET | Op::RET_K, k)
  def ret_a = ins(Op::RET | Op::RET_A)
  def ret_x = ins(Op::RET | Op::RET_X)
end

Minitest::Test.include TestHelper
