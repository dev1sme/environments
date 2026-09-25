-include .env

DOCKER=docker
DC=docker compose

ZONE=tools/coredns/zones/$(DOMAIN).db
SSL=tools/ssl-cert
DUMP=.data/dump
HOME_CFG=tools/homepage/config

.PHONY: domain-set cert-init db-dump db-restore up down rs reup build logs ls bash sh test reload vhosts home-gen cert dns-init dns-test psql db app-up app-down app-logs clean cg-up cg-down cg-build cg-index cg-status cg-ui cg-auth cg-mcp cg-sh

# help/menu tu chu thich ## — cu phap: tools/make/README.md
include tools/make/menu.mk
.DEFAULT_GOAL := help

#!var n        | Service (n)    | docker compose config --services
#!var p@cg-*   | Project (p)    | find "$PROJECTS_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
#!var p        | Project (p)    | find projects -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
#!var f        | File dump (f)  | ls -1t .data/dump/* | while read -r f; do printf '%s\t%s\n' "$f" "$(du -h "$f" | cut -f1)"; done
#!var d        | Domain (d)     |
#!var u        | User (u)       |
#!var force    | Ghi đè cert đang có? (force=1) | confirm
#!var pw       |                | skip

##@ Core
up: home-gen     ## bật proxy + postgres + coredns + homepage
	$(DC) up -d
down:           ## tắt hết
	$(DC) down
rs: down up     ## down rồi up lại
reup:           ## n=proxy | rebuild + up 1 service
	$(DC) up -d --build $(n)
build:
	$(DC) build $(n)
logs:           ## n=proxy | xem log (follow)
	$(DC) logs -f --tail=100 $(n)
ls:             ## liệt kê container đang chạy
	$(DOCKER) ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
bash:           ## n=proxy | vào shell container
	$(DC) exec $(n) bash
sh:
	$(DC) exec $(n) sh

##@ Proxy
test:           ## nginx -t, check config trước khi reload
	$(DC) exec proxy nginx -t
reload: test    ## reload nginx, KHÔNG đứt kết nối
	$(DC) exec proxy nginx -s reload
	@echo "proxy reloaded"
	@$(MAKE) --no-print-directory home-gen
vhosts:         ## liệt kê domain -> upstream + trạng thái
	@tools/proxy/vhosts.sh
# services.yaml cho homepage — ghi file tam roi mv de homepage khong doc file do dang.
home-gen:
	@tools/proxy/vhosts.sh --yaml > $(HOME_CFG)/.services.yaml.tmp && \
	 mv $(HOME_CFG)/.services.yaml.tmp $(HOME_CFG)/services.yaml
	@echo "wrote $(HOME_CFG)/services.yaml"
cert:           ## xem cert hiện tại
	@openssl x509 -in $(SSL)/self.crt -noout -subject -issuer -dates -ext subjectAltName

##@ Portability
domain-set:     ## d=new.local | ⚠ đổi domain nội bộ (sed toàn repo, cần commit trước)
	@test -n "$(d)" || { echo "thieu d=<domain-moi>, vd: d=mycompany.local"; exit 1; }
	@test -n "$(DOMAIN)" || { echo "DOMAIN chua set trong .env"; exit 1; }
	@test "$(d)" != "$(DOMAIN)" || { echo "d trung DOMAIN hien tai, khong lam gi"; exit 1; }
	@git diff --quiet HEAD 2>/dev/null || { \
		echo "working tree con thay doi chua commit."; \
		echo "commit truoc da — sed toan repo can co diem rollback."; exit 1; }
	@esc=$$(printf '%s' '$(DOMAIN)' | sed 's/\./\\./g'); \
	 files=$$( { git ls-files -z | xargs -0 grep -l "$$esc" 2>/dev/null; \
	             grep -l "$$esc" tools/proxy/conf.d/vhosts/*.conf 2>/dev/null; \
	           } | sort -u ); \
	 test -n "$$files" || { echo "khong file nao chua $(DOMAIN)"; exit 1; }; \
	 echo "sed $(DOMAIN) -> $(d) trong:"; \
	 printf '%s\n' "$$files" | sed 's/^/  /'; \
	 printf '%s\n' "$$files" | xargs sed -i "s/$$esc/$(d)/g"
	@sed -i 's/^DOMAIN=.*/DOMAIN=$(d)/' .env .env.example
	@rm -f $(ZONE)
	@echo ""
	@echo "xong. Buoc tiep:"
	@echo "  1. make dns-init          sinh lai zone cho $(d)"
	@echo "  2. make cert-init         cert cu chi phu domain cu, phai sinh lai"
	@echo "  3. make test && make reload"
	@echo "  4. git diff               doc lai truoc khi commit"
cert-init:      ## [d=...] [force=1] | sinh CA riêng + wildcard cert
	@d='$(if $(d),$(d),$(DOMAIN))'; \
	 test -n "$$d" || { echo "thieu d=<domain> va DOMAIN cung trong"; exit 1; }; \
	 if [ -f "$(SSL)/self.crt" ] && [ "$(force)" != "1" ]; then \
		echo "$(SSL)/self.crt DA TON TAI. Cert hien tai:"; \
		openssl x509 -in $(SSL)/self.crt -noout -subject -issuer -ext subjectAltName | sed 's/^/  /'; \
		echo ""; \
		echo "Ghi de la mat self.key vinh vien (file nay bi gitignore)."; \
		echo "Chac chan thi: make cert-init d=$$d force=1"; \
		exit 1; \
	 fi; \
	 ext=$$(mktemp); \
	 printf 'subjectAltName=DNS:%s,DNS:*.%s\nextendedKeyUsage=serverAuth\nkeyUsage=critical,digitalSignature,keyEncipherment\nbasicConstraints=critical,CA:FALSE\n' "$$d" "$$d" > "$$ext"; \
	 csr=$$(mktemp); \
	 openssl req -x509 -newkey rsa:4096 -sha256 -days 7300 -nodes \
		-keyout $(SSL)/ca.key -out $(SSL)/ca.crt \
		-subj "/CN=$$d Dev Root CA/O=$$d" \
		-addext 'basicConstraints=critical,CA:TRUE' \
		-addext 'keyUsage=critical,keyCertSign,cRLSign' 2>/dev/null; \
	 openssl req -newkey rsa:2048 -sha256 -nodes \
		-keyout $(SSL)/self.key -out "$$csr" \
		-subj "/CN=*.$$d" 2>/dev/null; \
	 openssl x509 -req -in "$$csr" -CA $(SSL)/ca.crt -CAkey $(SSL)/ca.key \
		-CAcreateserial -days 3650 -sha256 -extfile "$$ext" \
		-out $(SSL)/self.crt 2>/dev/null; \
	 rm -f "$$ext" "$$csr" $(SSL)/ca.srl; \
	 chmod 600 $(SSL)/ca.key $(SSL)/self.key; \
	 echo "sinh xong cho $$d:"; \
	 echo "  $(SSL)/ca.crt    <- CAI FILE NAY vao may/dien thoai can xem demo"; \
	 echo "  $(SSL)/ca.key    <- private key cua CA, gitignore, dung de mat"; \
	 echo "  $(SSL)/self.crt  $(SSL)/self.key"; \
	 echo ""; \
	 openssl verify -CAfile $(SSL)/ca.crt $(SSL)/self.crt; \
	 openssl x509 -in $(SSL)/self.crt -noout -subject -issuer -dates -ext subjectAltName
	@echo ""
	@echo "Roi: make test && make reload"

##@ DNS
dns-init:       ## sinh zone file từ HOST_IP trong .env
	@test -n "$(HOST_IP)" || { echo "HOST_IP chua set trong .env"; exit 1; }
	@test -n "$(DOMAIN)" || { echo "DOMAIN chua set trong .env"; exit 1; }
	@sed 's/__DOMAIN__/$(DOMAIN)/g; s/__HOST_IP__/$(HOST_IP)/g' \
		tools/coredns/zones/zone.db.example > $(ZONE)
	@echo "wrote $(ZONE) -> $(DOMAIN) @ $(HOST_IP)"
dns-test:       ## dig thử 1 domain qua coredns
	@dig +short @$(HOST_IP) whatever.$(DOMAIN) || true
	@dig +short @$(HOST_IP) example.com || true

##@ DB
psql:           ## vào psql
	$(DC) exec postgres psql -U $(POSTGRES_USER)
db:             ## p=myapp | tạo database cho app đang chạy
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) exec postgres psql -U $(POSTGRES_USER) -c "CREATE DATABASE $(p);"
db-dump:        ## pg_dumpall + gzip ra .data/dump/
	@mkdir -p $(DUMP)
	@f=$(DUMP)/all_$$(date +%Y%m%d_%H%M).sql.gz; \
	 $(DOCKER) exec env-postgres pg_dumpall -U $(POSTGRES_USER) | gzip > "$$f"; \
	 echo "wrote $$f ($$(du -h "$$f" | cut -f1))"
db-restore:     ## f=<file> | ⚠ restore (chỉ trên cluster mới init)
	@test -n "$(f)" || { echo "thieu f=<file>. Co san:"; ls -1 $(DUMP) 2>/dev/null | sed 's/^/  /'; exit 1; }
	@test -f "$(f)" || { echo "khong thay file $(f)"; exit 1; }
	@case "$(f)" in \
	  *.gz) gzip -dc "$(f)" | $(DOCKER) exec -i env-postgres psql -U $(POSTGRES_USER) -d postgres ;; \
	  *)    $(DOCKER) exec -i env-postgres psql -U $(POSTGRES_USER) -d postgres < "$(f)" ;; \
	 esac
	@echo "restored tu $(f)"

##@ App
app-up:         ## p=myapp | build + up projects/myapp
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) -f projects/$(p)/docker-compose.yml up -d --build
app-down:       ## p=myapp | tắt projects/myapp
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) -f projects/$(p)/docker-compose.yml down
app-logs:       ## p=myapp | log của projects/myapp
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) -f projects/$(p)/docker-compose.yml logs -f --tail=100

##@ codegraph
cg-build:       ## build image
	@test -n "$(PROJECTS_ROOT)" || { echo "PROJECTS_ROOT chua set trong .env"; exit 1; }
	$(DC) build codegraph
cg-up:          ## bật container
	@test -n "$(PROJECTS_ROOT)" || { echo "PROJECTS_ROOT chua set trong .env"; exit 1; }
	$(DC) up -d codegraph
cg-down:        ## tắt container
	$(DC) rm -sf codegraph
cg-sh:
	$(DC) exec codegraph bash
cg-auth:        ## u=<user> [pw=...] | sinh htpasswd cho UI
	@test -n "$(u)" || { echo "thieu u=<user>"; exit 1; }
	@if [ -n "$(pw)" ]; then pw='$(pw)'; \
	 else printf 'Password cho %s: ' '$(u)'; \
	      stty -echo 2>/dev/null; read pw; stty echo 2>/dev/null; echo; \
	 fi; \
	 docker run --rm httpd:alpine htpasswd -nbB '$(u)' "$$pw" \
		> tools/proxy/auth/codegraph.htpasswd
	@echo "wrote tools/proxy/auth/codegraph.htpasswd"
	@$(MAKE) --no-print-directory reload
# -y vi docker exec khong co TTY.
cg-index:       ## p=<project> | index 1 project
	@test -n "$(p)" || { echo "thieu p=<duong-dan-tuong-doi-trong-PROJECTS_ROOT>"; exit 1; }
	@if [ -d "$(PROJECTS_ROOT)/$(p)/.codegraph" ]; then \
		echo "[cg] re-index $(p)"; \
		$(DOCKER) exec -w $(PROJECTS_ROOT)/$(p) env-codegraph codegraph index; \
	else \
		echo "[cg] init + index $(p) (lan dau)"; \
		$(DOCKER) exec -w $(PROJECTS_ROOT)/$(p) env-codegraph codegraph init -y; \
	fi
cg-status:      ## p=<project> | trạng thái index
	@test -n "$(p)" || { echo "thieu p=<duong-dan-tuong-doi>"; exit 1; }
	@$(DOCKER) exec -w $(PROJECTS_ROOT)/$(p) env-codegraph codegraph status
cg-ui:
	@echo "codegraph v1.6.0 khong co lenh 'ui' (chi co tren branch main, chua release)."
	@echo "Kiem tra ban hien tai:  docker exec env-codegraph codegraph --help"
	@echo "Co release moi thi: bo comment codegraph-relay trong"
	@echo "tools/codegraph/docker-compose.yml, doi codegraph.conf.dist -> .conf,"
	@echo "make cg-auth u=<user>, make reload."
	@exit 1
cg-mcp:         ## p=<project> | in config MCP
	@test -n "$(p)" || { echo "thieu p=<duong-dan-tuong-doi>"; exit 1; }
	@echo 'Dan vao $(PROJECTS_ROOT)/$(p)/.mcp.json:'
	@echo '{'
	@echo '  "mcpServers": {'
	@echo '    "codegraph": {'
	@echo '      "command": "docker",'
	@echo '      "args": ["exec", "-i", "-w", "$(PROJECTS_ROOT)/$(p)",'
	@echo '               "env-codegraph", "codegraph", "serve", "--mcp"]'
	@echo '    }'
	@echo '  }'
	@echo '}'
	@echo ''
	@echo '-i thoi, KHONG -it: TTY lam hong framing JSON-RPC.'
clean:
	$(DOCKER) system prune
