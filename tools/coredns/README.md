# coredns — DNS nội bộ cho `*.$DOMAIN`

Để máy khác trong LAN gõ `myapp.thomson.cba` là biết đường về máy host, khỏi phải sửa `hosts` file trên từng máy client.

```
Corefile              config, dùng {$DOMAIN} nên không hardcode domain
zones/zone.db.example template, placeholder __DOMAIN__ / __HOST_IP__
zones/<domain>.db      zone thật, sinh bằng `make dns-init`, GITIGNORE
```

## LAN công ty đã có sẵn — service này đang DƯ

```
$ resolvectl status
DNS Servers: 10.11.11.10 10.11.11.11

$ dig @10.11.11.10 random-zzz9.thomson.cba
10.11.15.129
```

DNS công ty đã có wildcard `*.thomson.cba` trỏ về máy host. Tên nào cũng resolve, kể cả tên chưa tồn tại. Nên trong mạng này **không cần bật coredns** — điện thoại vào được `icms.thomson.cba` dù coredns chưa từng chạy.

Nó chỉ cần khi demo ở **mạng không phải LAN công ty**: nhà, office khách, hotspot điện thoại. Lúc đó bật lên rồi trỏ DNS của client về `HOST_IP`.

## Dùng

```bash
make dns-init            # sinh zones/<DOMAIN>.db tu .env
docker compose up -d coredns
make dns-test            # dig wildcard + dig ra internet
```

Client trỏ DNS về `HOST_IP`. Cách tốt nhất là set ở DHCP của router — mọi máy trong LAN tự nhận. Không sửa được router thì set DNS thủ công trên từng máy (vẫn hơn sửa `hosts` file, vì wildcard hoạt động: thêm app mới không phải sửa lại client).

Corefile có 2 block: zone `$DOMAIN` trả về `HOST_IP`, còn lại `forward . 1.1.1.1 8.8.8.8` — client trỏ DNS về đây vẫn duyệt internet bình thường, không cần cấu hình 2 DNS server.

## Mấy chỗ dễ sập

**Bind riêng vào `HOST_IP`, không bind `0.0.0.0`.** Host chạy systemd-resolved giữ `127.0.0.53:53`, bind all là `address already in use`. Đổi IP máy thì sửa `.env` rồi `make dns-init && make rs`.

**Mount cả thư mục, không mount lẻ từng file.** `make dns-init` tạo file zone mới — mount lẻ một file chưa tồn tại thì docker tạo nó thành directory, container start là lỗi.

**Domain lấy từ biến, đừng hardcode lại.** `Corefile` dùng `{$DOMAIN}` (env var substitution của CoreDNS), biến truyền từ compose. Đã verify: log in ra `thomson.cba.:53` đúng giá trị trong `.env`. Nên `make domain-set` không cần sed file này.

**`header { ... }` phải viết nhiều dòng.** Viết 1 dòng thì CoreDNS báo `plugin/header: setting up rule: unknown/unsupported flag=}` và không start.
