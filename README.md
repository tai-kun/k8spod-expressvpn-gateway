# k8spod-expressvpn-gateway

Inspired by [angelnu/pod-gateway](https://github.com/angelnu/pod-gateway).

## デフォルトの挙動

![design](./docs/assets/images/design.jpg)

1. vxlan11298 を作成する。
2. K8s 内での IP アドレスを返すサーバーと DNS を起動する。
3. Client Pod のトラフィック制限を行う。
   1. 基本的に全トラフィックを遮断する。
   2. 10.0.0.0/8 と 192.168.0.0/16 は通信を許可する。
   3. K8s 内での Gateway Pod の IP アドレスを取得する。
   4. vxlan11298 を作成する。
4. dhclient を使用して VXLAN 内での IP アドレスを取得・設定する。
5. 定期的に Gateway Pod との疎通を確認し、途切れた場合は 3. に戻る。
6. グローバル行きのトラフィックは expressvpn を経由する。
7. ローカル行きのトラフィックは expressvpn を経由しない。

## Gateway Pod の (K8s 内での) IP アドレス

![resource](./docs/assets/images/resource.jpg)

1. `curl -fs http://jp.expressvpn.cluster.local`
2. expressvpn が起動している Pod の IP アドレスが返ってくる。

Service 経由で Deployment に所属する Pod にアクセスすると、Pod の IP アドレスが提供される。
Service を使用して ExpressVPN で接続する国をグループ化し、Deployment で都市などの場所を整理することができる。
必ずしもこのような構成にする必要はないが、以下のようなアプローチで管理が簡素化される。

- 接続する国の追加や削除は、Service の変更で容易に行える。
- 都市などの場所の追加や削除は、Deployment の変更によって対応可能。
- 冗長性を確保するには、Deployment のレプリカ数を増やすことで対処可能。

## 設定例

`test/` ディレクトリを参照。
`test/run.sh` を実行すると、[kind](https://github.com/kubernetes-sigs/kind) と kubectl がダウンロードされるが、これは `.cache/bin` にダウンロードされるため、グローバル環境が影響を受けることは無いはず。

## 注意

実行には ExpressVPN のアクティベーションコードが必要。
