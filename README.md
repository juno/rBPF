# rBPF

Ruby BPF (Berkeley Packet Filter) simulator.

Linux の classic BPF (cBPF) を Ruby で実装した学習用シミュレーターです。A / X / scratch memory `M[0..15]` を持つレジスタマシンの動きを、読める規模のコードで追えます。eBPF は対象外です。

## 使い方

Ruby 4.0.7 (`mise.toml`)。外部 gem は不要です。

```ruby
require "rbpf"

Op = Rbpf::Op

# 命令は [code, jt, jf, k] (Linux の struct sock_filter と同じ)
prog = [
  Rbpf::Insn.new(Op::LD | Op::H | Op::ABS, 0, 0, 12),      # ldh [12]      ethertype
  Rbpf::Insn.new(Op::JMP | Op::JEQ | Op::K, 0, 1, 0x800),  # jeq #0x800
  Rbpf::Insn.new(Op::RET | Op::RET_K, 0, 0, 262144),       # ret #262144   accept
  Rbpf::Insn.new(Op::RET | Op::RET_K, 0, 0, 0)             # ret #0        drop
]

Rbpf.run(prog, packet)  # => 受理する長さ (0 なら破棄)
```

- 命令は `Rbpf::Insn` でも `[code, jt, jf, k]` の配列でも渡せます
- `packet` はバイナリ文字列です
- 実行前に verifier が検査し、不正なら `Rbpf::InvalidProgram` を投げます (`Rbpf.verify!` で検査だけもできます)
- パケット範囲外の読み出しと `X=0` の `div/mod` は、例外にせず返り値 0 で終了します (カーネルと同じ)

`tcpdump -dd` が出力する命令列をそのまま使えます。`test/tcpdump_filter_test.rb` に `ip and tcp dst port 80` の例があります。

## テスト

```
rake test
```

## 仕様

- 設計書: `docs/superpowers/specs/2026-09-29-rbpf-design.md`
- 未対応: `SKF_AD_*` (`ld #protocol` など) と負オフセット
- verifier は `net/core/filter.c` の `bpf_check_classic` と `check_load_and_stores` に合わせています
