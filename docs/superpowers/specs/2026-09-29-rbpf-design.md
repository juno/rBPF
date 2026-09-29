# rbpf 設計: Rubyによるcバークレー・パケットフィルタ(cBPF)シミュレーター

## 目的

レジスタマシンの学習。cBPFのA/X/scratch memoryと命令の動きを、Rubyの読めるコードで理解する。
eBPFは対象外。TDDで進める。

## 成功基準

命令配列とパケットを渡すと、実際のcBPFと同じ返り値になる。
最終確認として「IPv4/TCP/dst port 80 を受理する」tcpdump出力の命令列を通す。

## 構成

- `lib/rbpf.rb`: 公開API
  - `Rbpf.run(prog, packet)` → Integer(受理する長さ。0なら破棄)
  - `Rbpf.verify!(prog)` → 不正なら `Rbpf::InvalidProgram`
- `lib/rbpf/opcode.rb`: `linux/filter.h` と同じ数値の定数
- `lib/rbpf/verifier.rb`: 実行前検査
- `lib/rbpf/vm.rb`: 実行ループ
- `test/`: Minitest。命令クラスごとに1ファイル + 実例フィルタ

## データモデル

- 命令: `Insn = Struct.new(:code, :jt, :jf, :k)`。`[code, jt, jf, k]` の配列も受け付ける
- パケット: バイナリ文字列
- 状態: A, X, `M[0..15]`, pc。すべて32bit unsigned(演算ごとに `& 0xFFFFFFFF`)

## 実行の意味

- `ld/ldx`: W/H/B、abs/ind/imm/len/mem/msh。パケット読み出しはビッグエンディアン。`ind` は `X+k`
- `st/stx`: `M[k]` への書き込み
- ALU: `add sub mul div mod and or xor lsh rsh neg`。オペランドは K か X
- JMP: `ja` は `pc += k`。`jeq/jgt/jge/jset` は `jt/jf` の相対ジャンプ
- RET: K か A(`ret #k` / `ret a`。Linuxに `ret x` はない。`BPF_A` は 0x10 なので `ret a` = 0x16)
- MISC: `tax`, `txa`
- 範囲外のパケット読み出し、X=0 の `div/mod` は例外にせず返り値0で終了する(カーネル準拠)

## verifier

検査項目: 空プログラム、命令数4096超、未知opcode、範囲外ジャンプ、最終命令が `ret` でない、
フィールドの型と値域(code 0..0xFFFF、jt/jf 0..255、k 0..0xFFFFFFFF、整数)、`k=0` の `div/mod`、`M` の範囲外(`st/stx/ld mem/ldx mem`)、定数シフトの `k >= 32`、書き込み前のscratch読み出し(全経路で書き込み済みでなければ拒否。`net/core/filter.c` の `check_load_and_stores` と同じ方式)。

## 対象外(後回し)

- `SKF_AD_*`(`ld #protocol` など)と負オフセット
- eBPF全般

## 未確定(仮置き)

- (解決済み) シフト量: K版は `k >= 32` を verifier が拒否、X版は実行時に `X & 31`(`net/core/filter.c` と `kernel/bpf/core.c` で確認)
- テスト名は英語

## テスト方針

1. テストのみ先に書き、失敗を確認してコミット
2. テストを変更せず実装してパスさせる
3. 命令クラスごとの単体テスト → verifierの異常系 → tcpdump由来の実例
