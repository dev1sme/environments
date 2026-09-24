#!make
# Biến $(n) = tên service, $(p) = tên app.
-include .env

DOCKER=docker
DC=docker compose

# Derive tu DOMAIN trong .env — khong hardcode ten domain o day.
ZONE=tools/coredns/zones/$(DOMAIN).db
SSL=tools/ssl-cert
DUMP=.data/dump
CG_UI_PORT=4747

.PHONY: help menu domain-set cert-init db-dump db-restore up down rs reup build logs ls bash sh test reload cert dns-init dns-test psql db app-up app-down app-logs clean cg-up cg-down cg-build cg-index cg-status cg-ui cg-auth cg-mcp cg-sh

# Giao dien + mo ta tach ra tools/make/. Them target moi: sua targets.txt.
help:
	@sh tools/make/help.sh
menu:
	@bash tools/make/menu.sh



##############################################################
# Core
##############################################################
up:
	$(DC) up -d
	@:
down:
	$(DC) down
	@:
rs: down up
	@:
reup:
	$(DC) up -d --build $(n)
	@:
build:
	$(DC) build $(n)
	@:
logs:
	$(DC) logs -f --tail=100 $(n)
	@:
ls:
	$(DOCKER) ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@:
bash:
	$(DC) exec $(n) bash
	@:
sh:
	$(DC) exec $(n) sh
	@:

##############################################################
# Proxy
##############################################################
# nginx -s reload voi config sai thi nginx giu config cu va van chay, khong
# bao loi ro rang — nen `reload` goi `test` truoc. Xem tools/proxy/README.md
test:
	$(DC) exec proxy nginx -t
	@:
reload: test
	$(DC) exec proxy nginx -s reload
	@echo "proxy reloaded"
	@:
cert:
	@openssl x509 -in $(SSL)/self.crt -noout -subject -issuer -dates -ext subjectAltName
	@:

##############################################################
# Portability — doi domain / sinh cert rieng
##############################################################
# Sed toan repo -> bat buoc working tree sach de rollback duoc. Xem README.md
domain-set:
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
	@:

# Tu choi ghi de cert dang co tru khi force=1 (self.key gitignore, mat la mat
# vinh vien). Xem tools/ssl-cert/README.md
cert-init:
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
	@:

##############################################################
# DNS
##############################################################
dns-init:
	@test -n "$(HOST_IP)" || { echo "HOST_IP chua set trong .env"; exit 1; }
	@test -n "$(DOMAIN)" || { echo "DOMAIN chua set trong .env"; exit 1; }
	@sed 's/__DOMAIN__/$(DOMAIN)/g; s/__HOST_IP__/$(HOST_IP)/g' \
		tools/coredns/zones/zone.db.example > $(ZONE)
	@echo "wrote $(ZONE) -> $(DOMAIN) @ $(HOST_IP)"
	@:
dns-test:
	@dig +short @$(HOST_IP) whatever.$(DOMAIN) || true
	@dig +short @$(HOST_IP) example.com || true
	@:

##############################################################
# Database
##############################################################
psql:
	$(DC) exec postgres psql -U $(POSTGRES_USER)
	@:
# Script trong tools/postgres/init/ chi chay khi .data/postgres con trong.
# Postgres da chay truoc do thi tao DB bang target nay.
db:
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) exec postgres psql -U $(POSTGRES_USER) -c "CREATE DATABASE $(p);"
	@:

# pg_dumpall: gom moi database + role (can role de restore lai role hash md5).
# Nen nen luon — dump plain SQL cua DB 1.5GB la rat lon.
db-dump:
	@mkdir -p $(DUMP)
	@f=$(DUMP)/all_$$(date +%Y%m%d_%H%M).sql.gz; \
	 $(DOCKER) exec env-postgres pg_dumpall -U $(POSTGRES_USER) | gzip > "$$f"; \
	 echo "wrote $$f ($$(du -h "$$f" | cut -f1))"
	@:

# CHU Y: dump cua pg_dumpall chua CREATE ROLE/DATABASE — restore vao cluster
# da co san object se bao loi trung. Dung tren cluster moi init, hoac xoa
# .data/postgres truoc (xem tools/postgres/README.md).
db-restore:
	@test -n "$(f)" || { echo "thieu f=<file>. Co san:"; ls -1 $(DUMP) 2>/dev/null | sed 's/^/  /'; exit 1; }
	@test -f "$(f)" || { echo "khong thay file $(f)"; exit 1; }
	@case "$(f)" in \
	  *.gz) gzip -dc "$(f)" | $(DOCKER) exec -i env-postgres psql -U $(POSTGRES_USER) -d postgres ;; \
	  *)    $(DOCKER) exec -i env-postgres psql -U $(POSTGRES_USER) -d postgres < "$(f)" ;; \
	 esac
	@echo "restored tu $(f)"
	@:

##############################################################
# App trong projects/
##############################################################
app-up:
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) -f projects/$(p)/docker-compose.yml up -d --build
	@:
app-down:
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) -f projects/$(p)/docker-compose.yml down
	@:
app-logs:
	@test -n "$(p)" || { echo "thieu p=<app>"; exit 1; }
	$(DC) -f projects/$(p)/docker-compose.yml logs -f --tail=100
	@:

##############################################################
# codegraph
##############################################################
cg-build:
	@test -n "$(PROJECTS_ROOT)" || { echo "PROJECTS_ROOT chua set trong .env"; exit 1; }
	$(DC) build codegraph
	@:
cg-up:
	@test -n "$(PROJECTS_ROOT)" || { echo "PROJECTS_ROOT chua set trong .env"; exit 1; }
	$(DC) up -d codegraph
	@:
cg-down:
	$(DC) rm -sf codegraph
	@:
cg-sh:
	$(DC) exec codegraph bash
	@:

# Khong truyen pw= thi no hoi, khong vao shell history.
cg-auth:
	@test -n "$(u)" || { echo "thieu u=<user>"; exit 1; }
	@if [ -n "$(pw)" ]; then pw='$(pw)'; \
	 else printf 'Password cho %s: ' '$(u)'; \
	      stty -echo 2>/dev/null; read pw; stty echo 2>/dev/null; echo; \
	 fi; \
	 docker run --rm httpd:alpine htpasswd -nbB '$(u)' "$$pw" \
		> tools/proxy/auth/codegraph.htpasswd
	@echo "wrote tools/proxy/auth/codegraph.htpasswd"
	@$(MAKE) --no-print-directory reload
	@:

# Lan dau `init` (index luon), lan sau `index`. -y vi docker exec khong co TTY.
cg-index:
	@test -n "$(p)" || { echo "thieu p=<duong-dan-tuong-doi-trong-PROJECTS_ROOT>"; exit 1; }
	@if [ -d "$(PROJECTS_ROOT)/$(p)/.codegraph" ]; then \
		echo "[cg] re-index $(p)"; \
		$(DOCKER) exec -w $(PROJECTS_ROOT)/$(p) env-codegraph codegraph index; \
	else \
		echo "[cg] init + index $(p) (lan dau)"; \
		$(DOCKER) exec -w $(PROJECTS_ROOT)/$(p) env-codegraph codegraph init -y; \
	fi
	@:

cg-status:
	@test -n "$(p)" || { echo "thieu p=<duong-dan-tuong-doi>"; exit 1; }
	@$(DOCKER) exec -w $(PROJECTS_ROOT)/$(p) env-codegraph codegraph status
	@:

cg-ui:
	@echo "codegraph v1.6.0 khong co lenh 'ui' (chi co tren branch main, chua release)."
	@echo "Kiem tra ban hien tai:  docker exec env-codegraph codegraph --help"
	@echo "Co release moi thi: bo comment codegraph-relay trong"
	@echo "tools/codegraph/docker-compose.yml, doi codegraph.conf.dist -> .conf,"
	@echo "make cg-auth u=<user>, make reload."
	@exit 1

# Ban PER-PROJECT (-w) de co default project. Xem tools/codegraph/README.md
cg-mcp:
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
	@:

clean:
	$(DOCKER) system prune
	@:
