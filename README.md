# kiri_experiments

Experiments with [kiri](https://kiri.dev) as the container runtime on macOS.
Each experiment is a folder holding a `compose.yaml`, either at the repo root or
one level below it. Stacks under `productivity/` are daily drivers and stay up;
`smoke` is a test stack and is normally stopped.

## Layout

```
smoke/                  # a stack, and a group of stacks
  compose.yaml          # smoke itself: nginx proxy -> static app
  check.sh
  proxy/
  web/
  postgres/             # example of a nested stack
    compose.yaml
redis/                  # example of a root-level stack
  compose.yaml
Makefile                # make <target> <stack-path>
```

Discovery is one level deep, never recursive:

| Path | Stack? |
| --- | --- |
| `smoke/compose.yaml` | yes — `make up smoke` |
| `smoke/postgres/compose.yaml` | yes — `make up smoke/postgres` |
| `smoke/postgres/data/compose.yaml` | no, ignored |

A directory qualifies as a stack the moment it contains a `compose.yaml`; no
registration needed. Because project names default to the directory name, give
each `compose.yaml` a unique `name: ` (`kiri-<stack>`) so nested stacks with the
same leaf name don't collide.

## Usage

The stack path is passed as an argument after the target:

```sh
make list                        # stacks found in the repo
make up smoke                    # start a stack
make check smoke                 # run its check.sh, if any
make down smoke
make logs smoke
make clean smoke                 # also drop volumes

make ps                          # status of every stack
make ps smoke                    # status of one stack
make ps smoke/postgres           # nested stack

DOCKER=docker make up smoke      # different runtime/context
```

Also accepted: `STACK=smoke/postgres make up`, a trailing slash (`smoke/`), and
`.` when run from inside a stack directory:

```sh
cd smoke/postgres && make -f ../../Makefile up .
```

With exactly one stack in the repo the path may be omitted; as soon as a second
exists, `up`/`down`/`check`/`logs`/`clean` require it and list what's available.

## smoke (test stack — kept stopped)

A validation stack, not an everyday service. It stays down unless you are
checking kiri itself; `make up smoke` when you need it, `make down smoke` after.

Two containers, no build step, stock `nginx:alpine` for both:

```
browser ──▶ smoke-proxy (:8080) ──▶ smoke-app (:80, serves web/)
```

| Path | Purpose |
| --- | --- |
| `compose.yaml` | `app` (static site) and `proxy` (reverse proxy) on a private bridge network |
| `web/` | Static files bind-mounted into `app` |
| `proxy/nginx.conf` | Proxy config, including `/healthz` and `/upstream` |
| `check.sh` | Asserts proxy health, service discovery, and page content |

Endpoints once up:

- <http://127.0.0.1:8080/> — page served by `smoke-app` through `smoke-proxy`
- `/healthz` — answered by the proxy itself, so it stays green when the app is down
- `/upstream` — names the upstream container, confirming service discovery

### What it exercises

- `kiri compose` up/down/ps/logs/exec against the kiri socket
- compose healthchecks with `depends_on: condition: service_healthy`
- published port `8080` on the host
- bind mounts from the working tree into containers
- DNS-based service discovery on a user-defined bridge network
- proxy → app traffic without the app publishing any port

### Experiments to try

```sh
make restart smoke                   # does the stack come back cleanly?
make shell smoke                     # poke around a running container
kiri compose -f smoke/compose.yaml stop app   # `/` 502s, `/healthz` stays 200
kiri diag logs --errors              # kiri-side errors during the above
```

## productivity

Everyday apps, each independent and safe to leave running.

| Stack | URL | State | Notes |
| --- | --- | --- | --- |
| `productivity/memos` | <http://127.0.0.1:5230> | `./data` (SQLite) | Quick notes. Single binary, in-container healthcheck |
| `productivity/vikunja` | <http://127.0.0.1:3456> | `./data/files` (SQLite) | Tasks/kanban. Distroless image: no shell, so `make check` probes from the host |
| `productivity/stirling-pdf` | <http://127.0.0.1:8081> | `./data/{configs,logs,pipeline}` | PDF toolbox. Host port 8081 since smoke owns 8080 |

```sh
make up productivity/memos
make check productivity/memos
make down productivity/memos
```

Things worth knowing:

- `vikunja` sets `VIKUNJA_SERVICE_JWTSECRET` to a development default. Override it
  with `VIKUNJA_SERVICE_JWTSECRET=... make up productivity/vikunja` if the port is
  ever reachable beyond this machine.
- `stirling-pdf` deliberately does not bind-mount tessdata: an empty directory over
  it silently breaks OCR. Copy real data into `./data/tessdata` first if you want
  extra languages.
- Runtime state lives in `data/` and is gitignored; `make clean <stack>` drops
  containers and volumes, but leaves `data/` alone so notes and PDFs survive.

## Port map

Stacks run independently; only these ports are taken while they are up.

| Port | Stack | Everyday? |
| --- | --- | --- |
| 3456 | vikunja | yes |
| 5230 | memos | yes |
| 8081 | stirling-pdf | yes |
| 8080 | smoke (proxy) | no — test stack, normally stopped |
