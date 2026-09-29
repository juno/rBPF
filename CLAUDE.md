# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Linux の classic BPF (cBPF) を Ruby で書いた学習用シミュレーター。eBPF は対象外。外部 gem なし (Minitest + Rake のみ)。

## コマンド

- 全テスト: `rake test`
- 1ファイル: `ruby -Ilib -Itest test/verifier_test.rb`
- 1テスト: `ruby -Ilib -Itest test/alu_test.rb -n test_neg`

## アーキテクチャ

`Rbpf.run(prog, packet)` は `Rbpf.compile(prog)`(`normalize` → `Verifier.verify!` → 命令のコピーを凍結)で作った `Program` に `#run(packet)` を呼ぶだけ。繰り返し使うなら `compile` の結果を持つ。

- `lib/rbpf/opcode.rb`: `linux/filter.h` と同じ数値の `Rbpf::Op`。**オペコードの数値を変えるときは `test/opcode_test.rb` の tcpdump 由来の値と照合する**(過去に `ret a` の値を誤った: 正しくは `RET|RET_A` = 0x16。Linux に `ret x` はない)
- `lib/rbpf/verifier.rb`: Linux の `bpf_check_classic` と `check_load_and_stores` を Ruby で再現している。許可するオペコードは `*_CODES` の表で持つ。不正な値は必ず `InvalidProgram` にする(負の `jt/jf/k` などがすり抜けると VM が無限ループする)
- `lib/rbpf/vm.rb`: `Rbpf::VM` は `private_constant`。verifier を通っていない命令列を渡す経路を作らない

## 仕様上の判断(カーネル準拠)

- パケット範囲外の読み出しと `X=0` の `div/mod` は、例外にせず返り値0でプログラムを終了する(`throw :ret, 0`)
- シフト: K 版の `k >= 32` は verifier が拒否、X 版は実行時に `X & 31`
- A/X/`M[0..15]` は32bit unsigned。ALU の結果は必ず `& MASK` する
- `SKF_AD_*` と負オフセットは未対応

不明点は推測せず、`net/core/filter.c` と `kernel/bpf/core.c` の実ソースで確認する(過去に記憶と実装が食い違った)。

## 開発の進め方

- TDD: 先にテストだけ書いて失敗を確認し、テストをコミットしてから実装する
- 設計書と実装計画は `docs/superpowers/specs/` と `docs/superpowers/plans/`。仕様を変えたら設計書も更新する(計画書は当時の記録として直さない)
- コミットは署名にハードウェアキーが必要なため、サンドボックス内では失敗する
