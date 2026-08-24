<div align="center">

<img src="docs/img/appicon.png" width="112" alt="SlimeZIP">

# SlimeZIP

### 目的のアイコンを探してメニューバーを見渡すのは、もう終わりです

Mac のメニューバーのアイコンを、**スライムが一匹まとめて飲み込みます。**
必要なものだけ残し、あとはワンクリックで出し入れします。

<br>

[한국어](README.md) · [English](README.en.md) · **日本語** · [简体中文](README.zh.md)

[**インストール**](docs/INSTALL.md) · [紹介ページ](https://aisyncclub.github.io/slimezip/) · [最新リリース](https://github.com/aisyncclub/slimezip/releases/latest)

[![GitHub stars](https://img.shields.io/github/stars/aisyncclub/slimezip?style=for-the-badge&logo=github&label=%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%92%E4%BB%98%E3%81%91%E3%82%8B&color=f5c518)](https://github.com/aisyncclub/slimezip/stargazers)
[![macOS](https://img.shields.io/badge/macOS-14%2B-0f7a66?style=for-the-badge&logo=apple&logoColor=white)](docs/INSTALL.md)
[![License](https://img.shields.io/badge/%E7%84%A1%E6%96%99-%E3%82%AA%E3%83%BC%E3%83%97%E3%83%B3%E3%82%BD%E3%83%BC%E3%82%B9-0a5d4e?style=for-the-badge)](#ライセンス)

**役に立ったなら、スター一つが何よりの報酬です。**

</div>

> [!TIP]
> **アプリは英語表示に対応しています。** 初回起動時にシステムの言語設定に従うので、
> 日本語環境では英語で表示されます（韓国語以外はすべて英語になります）。手動で変えるには
> **スライムを右クリック → 設定 → 制作者 → このアプリ → Language** で
> `English` / `한국어` / `Follow system` を選びます。切り替えは即座に反映され、再起動は不要です。
>
> 日本語表示はまだありません。必要でしたら
> [Issue](https://github.com/aisyncclub/slimezip/issues) でお知らせください。
> なお、ご自分で付けたグループ名は入力したまま残ります。

<br>

<img src="docs/img/hero.png" alt="SlimeZIP なしで溢れたメニューバーと、スライム一匹が残りを抱えているメニューバー">

<br>

## 何が問題か

MacBook・Mac Studio・Mac mini で、アイコンが 20 個を超えたあたりから三つのことが同時に起きます。

| | |
|---|---|
| **溢れた分は黙って消える** | 警告も印もなく、左から切り落とされます。ノッチがあればもっと早く消えます。 |
| **どのアプリのものか分からない** | macOS 26 以降はコントロールセンターが代わりに描画するため、ウインドウ情報だけでは持ち主を特定できません。 |
| **動かす手段が ⌘ドラッグだけ** | 一つずつ引きずって、どこに置いたかまた忘れます。 |

---

## どんな画面か

<table>
<tr>
<td width="42%" valign="top">

<img src="docs/img/ui-panel.png" alt="スライムをクリックすると開くパネル">

</td>
<td valign="top">

### スライムを押すと開くパネル

今バーにあるアイコンが、**持ち主のアプリ名つきで**すべて並びます。

- 上の青いボタン — **出す / しまう**。再起動なしで即座に
- 各行の `‹ ›` — 並び替え
- 各行の **入れる・出す** — 非表示グループの内外へ移動
- オレンジの帯 — 適用待ちのアプリとその数
- 最下部 — バージョン・アップデート確認・制作者・バナー

</td>
</tr>
</table>

<table>
<tr>
<td valign="top">

<img src="docs/img/ui-welcome.png" alt="設定のはじめに画面">

**はじめに** — 初回はここが開きます。3 ステップの使い方とチュートリアル。

</td>
<td valign="top">

<img src="docs/img/ui-icons.png" alt="設定のアイコン一覧">

**アイコン** — まとめて整理するときに便利な広い一覧。

</td>
</tr>
<tr>
<td valign="top">

<img src="docs/img/ui-creator.png" alt="設定の制作者画面">

**制作者** — 各種リンクと、このコピーのバージョン・アップデート。

</td>
<td valign="top">

<img src="docs/img/ui-diagnostics.png" alt="設定の診断画面">

**診断** — この Mac で何ができて何ができないか。

</td>
</tr>
</table>

---

## 何ができるか

### 潰れたスライム — アイコン幅は 22pt のまま

<img src="docs/img/scale.png" alt="隠した数が 0 から 5 以上に増えるにつれて平たくなるスライム">

**隠す数が増えてもアイコンの幅は変わりません。** 数字を出せば場所を取るので、
代わりに同じ枠の中でスライム同士が押し合って潰れます。まばたきもしますし、呼吸もします。

### そのほか

| | |
|---|---|
| **名前で識別** | アクセシビリティ権限で各アプリが公開している情報を読み、Tailscale なのか何なのかを名前で表示します。この Mac では 43 個中 35 個が名前まで判明しました。 |
| **ボタンで出し入れ** | ⌘ドラッグと格闘する必要はありません。 |
| **並び替え** | `‹ ›` で左右に動かします。 |
| **SlimeZIP 自身の位置も移動** | パネルの「位置 `‹ ›`」。自分のアイテムなので再起動も不要です。 |
| **隠している間の変化を通知** | 隠したアイコンの絵が変わるとスライムがピクッと動き、オレンジの点が付きます。 |
| **グループ** | 複数のグループを作り、別々に畳めます。「常に非表示」グループは通常のクリックでは開きません。 |
| **アップデート確認** | 新しいバージョンが出るとパネルに表示され、ボタン一つで取得して自分自身を置き換えます。 |
| **English · 한국어** | システムの言語設定に従います。設定 → 制作者 → このアプリ → Language で直接選ぶこともでき、切り替えは即座に反映されます。 |
| **待機中の CPU は 0.0%** | ポーリングしません。 |

---

## インストール

### ダウンロードして

1. [リリース](https://github.com/aisyncclub/slimezip/releases/latest)から `SlimeZIP-*.zip` を入手
2. 展開して `SlimeZIP.app` を**アプリケーション**へ移動
3. 初回起動は macOS がブロックします → **システム設定 → プライバシーとセキュリティ**の一番下、**このまま開く**
4. **システム設定 → アクセシビリティ**で SlimeZIP をオンに

> **右クリック → 開く はもう使えません。** macOS Sequoia でその抜け道が塞がれました。
> 手順 3 のシステム設定経路だけが残っています。ウェブ上の古い案内が右クリックと書いていたら、
> それは Sequoia より前の話です。

### ターミナルに慣れているなら

```bash
curl -fsSL https://raw.githubusercontent.com/aisyncclub/slimezip/master/scripts/install.sh | bash
```

手順 3 を省けるだけで、やっていることは同じです。
[スクリプトを先に読んでも構いません](scripts/install.sh)。

画像つきの手順と困ったときの対処は [docs/INSTALL.md](docs/INSTALL.md)（韓国語）にあります。

---

## 使い方

動作は二種類あり、**毎日使うほうは再起動が要りません。**

| 動作 | 再起動 | 頻度 |
|---|---|---|
| パネル上部の **出す / しまう** | **なし** | 毎日 |
| 各行の **入れる・出す** | そのアプリ 1 回 | 定位置を決めるときだけ |

青いボタンは区切りの長さを伸縮させるだけです。保存された位置に触れないので即座に反映されます。

行の入れる・出すは、アイコンを境界の**向こう側へ移してしまう**操作なので、macOS が保存している
位置を書き換えます。macOS はその値を**アプリの起動時にしか読まない**ため、そのアプリを一度だけ
再起動します。一つのアプリに複数のアイコンがあっても、再起動は一度です。

### 操作一覧

| | |
|---|---|
| **クリック** | パネルを開く |
| **⌥ + クリック** | 畳む ↔ 広げる を直接切り替え |
| **右クリック** | 設定・終了メニュー |

### コントロールセンターのアイコンは例外です

Wi-Fi・バッテリー・サウンド・Bluetooth は macOS 26 ではコントロールセンターが描画します。
位置を書き込むところまではできますが、アイコン一つのためにメニューバーの半分を描いている
プロセスを落とすのは、このアプリが勝手に決めていい取引ではありません。該当する項目は
再起動ボタンではなく **「次回ログイン時に適用」** と表示されます。

---

## 仕組み

macOS はこの領域を二回続けて壊しました。macOS 26 Tahoe がウインドウの所有者情報を汚し、
macOS 27 Golden Gate がメニューバーの構造そのものを作り替えたことで、Bartender・Ice・
Barbee・Thaw・BetterTouchTool のメニューバー機能がすべて動かなくなりました。実測は
[docs/RESEARCH.md](docs/RESEARCH.md)（韓国語）にあります。

そこで設計原則は**実行時の能力判定**です。機能をハードコードせず、OS に尋ねて、できることだけを
UI に出します。できないときは黙って失敗せず、バナーで伝えます。

```
UI  ────────────────────────  Capabilities に応じて機能を出し入れ
MenuBarEngine  ─────────────  グループ・順序・状態の唯一の真実
HidingStrategy (プロトコル) ─  ★ OS が変わってもここまでしか書き直さない
  └ SpacerStrategy           長さの膨張 · 権限ゼロ · macOS 14–26
  └ (Phase 2) BridgeStrategy 列挙 · 移動 · リモートクリック
```

### 隠す仕組み

グループごとに、見えない**区切り**を一つバーに置きます。畳むときにその区切りの長さを画面幅の
二倍に膨らませると、**区切りより左にあるアイコンがすべて画面外へ**押し出されます。広げるときは
1pt に戻します。権限も非公開 API も要りません。

つまり「隠す」とは**区切りの左に置く**ことであり、アイコンをそちらへ動かす瞬間だけが、保存された
位置を書き換える唯一の場面です。

### 実測値

すべて同じ一台（Mac Studio, macOS 26.5）で計測した値です。

| | |
|---|---|
| **43 個** | アクセシビリティ走査で列挙されたメニューバー項目 |
| **35 個** | アプリ名まで判明したアイコン |
| **22pt** | 隠した数によらず変わらないアイコン幅 |
| **0.0%** | 待機中の CPU 使用率 |

macOS が何を許し何を拒むかも測りました。

| | |
|---|---|
| 列挙・識別 | ✅ アクセシビリティ走査で可能 |
| 非表示 | ✅ 区切りの長さの膨張で可能 |
| リモートクリック | ✅ `AXPress` で可能 |
| アクセシビリティ経由の位置書き込み | ❌ 34 個中 0 個成功 |
| 合成 ⌘ドラッグ | ❌ 0pt しか動かず |
| 保存位置の書き込み + 対象アプリの再起動 | ✅ 可能（461 → 792 を確認） |

最後の行が現在の方式です。

### まだできないこと

- すでにノッチの裏に隠れたアイコンは、この方式では取り出せません
- 画面収録インジケータのようにシステムが優先する項目は隠せません
- 隠したアプリの**未読件数**は分かりません。macOS が他アプリのバッジ状態を公開しないためで、
  代わりにアイコンの絵が変わるとスライムが反応します

---

## プライバシーとネットワーク

**6 時間に一度、しかもパネルを開いたときだけ、二か所を読みます。**

| 何を | どこから |
|---|---|
| 新しいバージョンの有無 | `api.github.com/repos/aisyncclub/slimezip` |
| 下部の帯に出す文言 | [`app-config.json`](web/app-config.json)（このリポジトリの GitHub Pages） |

**送信は一切ありません。** アイコン一覧も、利用状況も、識別子も、どこにも上がりません。
アクセシビリティ権限は**読み取りにのみ**使います — キー入力の傍受も記録もしません。
[ソース](Sources/ZipBarKit/Services)で確認できます。

止めるには:

```bash
defaults write com.zipbar.ZipBar com.zipbar.checkForUpdates -bool NO
```

ボタンで押す「アップデート確認」はこの設定と無関係に動きます。頼んでもいないのに連絡されたく
ないことと、尋ねたときに答えが返ってこないことは別の話です。

---

## 開発

Xcode は不要です。Command Line Tools だけでビルドできます。

```bash
swift build && swift test     # ビルド + テスト 113 件
./scripts/build-app.sh        # dist/SlimeZIP.app を生成
./scripts/release.sh v0.2.0   # バージョン記録・ビルド・圧縮・GitHub リリース
```

### 診断

OS アップデート後、とくにベータでは真っ先にこれを回します。

```bash
./.build/debug/zipbar-probe capabilities   # 各バックエンドがここで何をできるか
./.build/debug/zipbar-probe list           # 列挙結果すべて
./.build/debug/zipbar-probe ax             # アクセシビリティ走査の詳細（権限が必要）
```

UI は主張ではなく描いて確認します。以下の環境変数で実行すると、実際のビュー階層を PNG に
書き出します — 画面収録権限も、人が座っている必要もありません。

```bash
ZIPBAR_PROBE_PANEL_SHOT=1     ZIPBAR_PANEL_OUT=/tmp/panel.png      # パネル
ZIPBAR_PROBE_SETTINGS_SHOT=1  ZIPBAR_SETTINGS_TAB=creator          # 設定（タブ指定）
ZIPBAR_PROBE_UPDATE=1                                              # アップデート全工程
```

この README の画面写真も、すべてこれで撮っています。

### 配布上の制約

アクセシビリティ権限を使うため、**サンドボックス化できず Mac App Store にも出せません。**
直接配布が唯一の経路です。

Apple の公証（notarization）はまだ受けていません — 年 99 ドルの Developer ID が必要だからです。
そのため初回起動でシステム設定を一度経由します。公証を受ければその手順は消え、Homebrew cask
への登録も可能になります。

### コントリビュート

不具合報告と Pull Request を歓迎します。
[Issue](https://github.com/aisyncclub/slimezip/issues) に**何をしようとして、どこで止まったか、
macOS のバージョンとあわせて**書いていただけると助かります。

---

## ライセンス

無料で、ソースは公開されています。

`Ice` は GPL-3.0 です。将来のライセンス選択の自由を残すため、**Ice のソースは読みも参照もして
いません。** 挙動だけを観察しています。

---

<div align="center">

**ここまで読んでくださったなら、スター一つお願いします。** ⭐

[![GitHub stars](https://img.shields.io/github/stars/aisyncclub/slimezip?style=for-the-badge&logo=github&label=%E3%82%B9%E3%82%BF%E3%83%BC%E3%82%92%E4%BB%98%E3%81%91%E3%82%8B&color=f5c518)](https://github.com/aisyncclub/slimezip/stargazers)

<sub>SlimeZIP · Ai싱크클럽 (AI Sync Club) 制作 · macOS 14+ · 無料 · オープンソース</sub>

</div>
