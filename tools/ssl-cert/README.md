# ssl-cert — wildcard cert cho `*.$DOMAIN`

```
self.crt    leaf cert, nginx dùng cái này
self.key    private key, GITIGNORE
ca.crt      root CA (chỉ có khi sinh bằng `make cert-init`)
ca.key      private key của CA, GITIGNORE
```

`self.crt` có commit vào git — đó là cert public, máy khác cần nó để đối chiếu. `*.key` thì không bao giờ.

## Cert hiện tại

**Không phải self-signed.** Do `CYBRIDGE ASIA Root CA` cấp (mkcert), root CA đó nằm ở `/usr/local/share/ca-certificates/mkcert-rootCA-CBA.cer`, hết hạn 2045.

```bash
make cert    # subject, issuer, SAN, ngay het han
```

```
subject=... CN = Web Development 2026
issuer=...  CN = CYBRIDGE ASIA Root CA
SAN:        DNS:thomson.cba, DNS:*.thomson.cba
```

Máy nào đã cài root CA đó thì vào HTTPS không cảnh báo gì — đó là lợi thế ở LAN công ty hiện tại, cả LAN đã trust sẵn.

## Cho điện thoại / máy khách xem demo

Thiết bị chưa cài root CA sẽ hiện cảnh báo. Bấm "vẫn tiếp tục" là xem được trang, nhưng exception đó **chỉ áp cho đúng 1 host** — subresource từ host khác vẫn bị chặn im lặng (xem `tools/proxy/README.md`).

Muốn hết cảnh báo: copy `/usr/local/share/ca-certificates/mkcert-rootCA-CBA.cer` sang thiết bị rồi cài.

- **iOS** — mở file bằng Safari → Settings → *Profile Downloaded* → Install. Rồi **bắt buộc** vào Settings → General → About → Certificate Trust Settings → bật full trust cho CA đó. Thiếu bước cuối là cài rồi vẫn cảnh báo.
- **Android** — Settings → Security → Encryption & credentials → Install a certificate → **CA certificate**, không phải "VPN & app user certificate".

Cài 1 lần dùng cho mọi app `*.$DOMAIN` về sau.

## `make cert-init [d=<domain>]` — sinh CA riêng

Dùng khi không có sẵn root CA của công ty (đổi công ty, demo ở mạng khác). Sinh bằng `openssl`, không cần cài `mkcert`.

```bash
make cert-init d=mycompany.local
```

Ra 4 file: `ca.crt` (cài vào thiết bị), `ca.key`, `self.crt` (SAN: `<domain>` + `*.<domain>`), `self.key`. Key `chmod 600`. CA hạn 20 năm, leaf 10 năm.

CA có `basicConstraints=critical,CA:TRUE` nên **cài được như CA thật** trên iOS/Android — khác cert công ty hiện tại (là leaf, không phải CA).

**Nó từ chối ghi đè `self.crt` đang có** trừ khi `force=1`. Lý do: `self.key` bị gitignore nên ghi đè là **mất vĩnh viễn**, git không cứu được. Guard này in cert hiện tại ra rồi thoát, không chạm file nào.

Verify:

```bash
openssl verify -CAfile tools/ssl-cert/ca.crt tools/ssl-cert/self.crt
make cert
make test && make reload
```

Đổi domain thì cert cũ vô giá trị (SAN không khớp) — phải `make cert-init` lại. Xem `make domain-set` ở README gốc.
