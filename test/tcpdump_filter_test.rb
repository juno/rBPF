require "test_helper"

class TcpdumpFilterTest < Minitest::Test
  ACCEPT = 262144

  def prog
    @prog ||= [
      ins(Op::LD | Op::H | Op::ABS, 12),                 # 0: ethertype
      ins(Op::JMP | Op::JEQ | Op::K, 0x800, 0, 8),       # 1: IPv4 でなければ 10 へ
      ins(Op::LD | Op::B | Op::ABS, 23),                 # 2: protocol
      ins(Op::JMP | Op::JEQ | Op::K, 6, 0, 6),           # 3: TCP でなければ 10 へ
      ins(Op::LD | Op::H | Op::ABS, 20),                 # 4: flags/fragment offset
      ins(Op::JMP | Op::JSET | Op::K, 0x1fff, 4, 0),     # 5: フラグメントなら 10 へ
      ins(Op::LDX | Op::B | Op::MSH, 14),                # 6: X = IHL * 4
      ins(Op::LD | Op::H | Op::IND, 16),                 # 7: TCP dst port
      ins(Op::JMP | Op::JEQ | Op::K, 80, 0, 1),          # 8: 80 でなければ 10 へ
      ret_k(ACCEPT),                                     # 9
      ret_k(0)                                           # 10
    ]
  end

  def packet(ethertype: 0x0800, proto: 6, frag: 0, ihl: 5, dport: 80)
    eth = ("\0" * 12) + [ethertype].pack("n")
    ip = [0x40 | ihl, 0, 40, 0, frag, 64, proto, 0, 0, 0].pack("CCnnnCCnNN")
    ip += "\0" * ((ihl - 5) * 4)
    tcp = [12345, dport].pack("nn") + ("\0" * 16)
    (eth + ip + tcp).b
  end

  def test_accepts_tcp_port_80
    assert_equal ACCEPT, Rbpf.run(prog, packet)
  end

  def test_accepts_with_ip_options
    assert_equal ACCEPT, Rbpf.run(prog, packet(ihl: 6))
  end

  def test_rejects_other_port
    assert_equal 0, Rbpf.run(prog, packet(dport: 22))
  end

  def test_rejects_non_ipv4
    assert_equal 0, Rbpf.run(prog, packet(ethertype: 0x0806))
  end

  def test_rejects_udp
    assert_equal 0, Rbpf.run(prog, packet(proto: 17))
  end

  def test_rejects_fragment
    assert_equal 0, Rbpf.run(prog, packet(frag: 0x0001))
  end

  def test_rejects_truncated_packet
    assert_equal 0, Rbpf.run(prog, packet[0, 20])
  end
end
