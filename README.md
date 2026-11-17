# kiri_experiments

Experiments with [kiri](https://kiri.dev) as the container runtime on macOS.
Each experiment is a folder holding a `compose.yaml`, either at the repo root or
one level below it.

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

## smoke

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
make down && make up                 # does the stack come back cleanly?
kiri compose stop app                # `/` should 502, `/healthz` still 200
make shell                           # poke around a running container
kiri diag logs --errors              # kiri-side errors during the above
```
