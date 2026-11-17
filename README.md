# kiri_experiments

Experiments with [kiri](https://kiri.dev) as the container runtime on macOS.
Each experiment lives in its own self-contained directory under `tests/`.

## Layout

```
tests/
  smoke/            # minimal two-container stack
    compose.yaml
    check.sh        # assertions for this test
    proxy/          # nginx reverse-proxy config
    web/            # static files served by the app container
Makefile            # wrappers: TEST=<name> make up|check|down|...
```

Every test directory is created the same way:

```
tests/<name>/
  compose.yaml   # the stack
  check.sh       # executable; exits non-zero on failure
```

`make` targets default to `TEST=smoke`:

```sh
make list          # show available tests
make up            # start tests/smoke
make check         # run tests/smoke/check.sh
make ps
make logs
make down
make clean         # also drop volumes

make up TEST=<name>      # any other test
DOCKER=docker make up    # run against a different runtime/context
```

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
