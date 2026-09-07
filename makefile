#!make
# Bê pattern từ docker-starfish/makefile. Biến $(n) = tên service, $(p) = tên app.
-include .env

DOCKER=docker
DC=docker compose

ZONE=tools/coredns/zones/thomson.cba.db
CG_UI_PORT=4747

.PHONY: help up down rs reup build logs ls bash sh test reload cert dns-init dns-test psql db app-up app-down app-logs clean cg-up cg-down cg-build cg-index cg-status cg-ui cg-auth cg-mcp cg-sh

help:
	@echo "Core:"
	@echo "  make up                    bat proxy + postgres + coredns"
	@echo "  make down                  tat het"
	@echo "  make rs                    down roi up lai"
	@echo "  make reup n=proxy          rebuild + up 1 service"
	@echo "  make logs n=proxy          xem log (follow)"
	@echo "  make ls                    liet ke container dang chay"
	@echo "  make bash n=proxy          vao shell container"
	@echo ""
	@echo "Proxy:"
	@echo "  make test                  nginx -t, check config truoc khi reload"
	@echo "  make reload                reload nginx, KHONG dut ket noi"
	@echo ""
	@echo "DNS:"
	@echo "  make dns-init              sinh zone file tu HOST_IP trong .env"
	@echo "  make dns-test              dig thu 1 domain qua coredns"
	@echo ""
	@echo "DB:"
	@echo "  make psql                  vao psql"
	@echo "  make db p=myapp            tao database cho app dang chay"
	@echo ""
	@echo "App:"
	@echo "  make app-up p=myapp        build + up projects/myapp"
	@echo "  make app-down p=myapp      tat projects/myapp"
	@echo "  make app-logs p=myapp      log cua projects/myapp"
	@echo ""
	@echo "codegraph:"
	@echo "  make cg-build              build image"
	@echo "  make cg-up / cg-down       bat/tat container"
	@echo "  make cg-auth u=thomson     sinh htpasswd cho UI"
	@echo "  make cg-index p=thomson/demo   index 1 project"
	@echo "  make cg-status p=thomson/demo  trang thai index"
	@echo "  make cg-mcp p=thomson/demo     in config MCP"



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
# Luon `make test` truoc `make reload`. nginx -s reload voi config sai thi
# nginx giu config cu va van chay — nhung khong co bao loi ro rang.
test:
	$(DC) exec proxy nginx -t
	@:
# reload thay vi restart: worker cu phuc vu xong request dang do moi thoat.
# Restart thi dut het ket noi dang mo, ke ca demo dang chay.
reload: test
	$(DC) exec proxy nginx -s reload
	@echo "proxy reloaded"
	@:
cert:
	@openssl x509 -in tools/ssl-cert/self.crt -noout -subject -dates -ext subjectAltName
	@:

##############################################################
# DNS
##############################################################
dns-init:
	@test -n "$(HOST_IP)" || { echo "HOST_IP chua set trong .env"; exit 1; }
	@sed 's/__HOST_IP__/$(HOST_IP)/g' $(ZONE).example > $(ZONE)
	@echo "wrote $(ZONE) -> $(HOST_IP)"
	@:
dns-test:
	@dig +short @$(HOST_IP) whatever.thomson.cba || true
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
# Compose cua codegraph nam o tools/codegraph/docker-compose.yml, root include
# vao nen cung 1 project — goi thang bang ten service, khong can -f.
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

# UI bi khoa bang basic auth vi no doc graph cua source code.
# Khong truyen pw= thi no hoi, khong hien ra man hinh va khong vao shell history.
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

# Lan dau phai `init` (no index luon). Lan sau moi dung `index`.
# -y de khong prompt: docker exec khong co TTY.
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

# Phuong an A (UI 1 domain, doi project theo yeu cau) CHUA LAM DUOC:
# release v1.6.0 khong co lenh `ui`, chi branch main moi co.
cg-ui:
	@echo "codegraph v1.6.0 khong co lenh 'ui' (chi co tren branch main, chua release)."
	@echo "Kiem tra ban hien tai:  docker exec env-codegraph codegraph --help"
	@echo "Co release moi thi: bo comment codegraph-relay trong"
	@echo "tools/codegraph/docker-compose.yml, doi codegraph.conf.dist -> .conf,"
	@echo "make cg-auth u=<user>, make reload."
	@exit 1

# MCP config. Dung ban PER-PROJECT (-w) de co default project:
# khong co -w thi server bao "no default project" va moi tool call phai
# tu truyen projectPath.
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
