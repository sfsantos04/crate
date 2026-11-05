#!/usr/bin/env python3
"""Conformance test: verifica que a API do slskd entrega exatamente o que
o app Sonda decodifica. Roda contra um slskd real; não imprime segredos.

Uso:
    python3 tools/conformance.py --host http://SEU_HOST:5030 \
        --user "$SLSKD_USER" --password "$SLSKD_PASS"
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request

PASS, FAIL = "PASS", "FAIL"
results = []


def check(name, condition, detail=""):
    results.append((PASS if condition else FAIL, name, detail))
    print(f"[{PASS if condition else FAIL}] {name}{(' — ' + detail) if detail and not condition else ''}")


def type_ok(value, kinds, allow_none=True):
    if value is None:
        return allow_none
    if isinstance(value, bool) and bool in kinds:
        return True
    if isinstance(value, int) and bool not in kinds and int in kinds:
        return True
    if isinstance(value, float) and (float in kinds or int in kinds) and not isinstance(value, bool):
        return True
    return isinstance(value, kinds)


class Client:
    def __init__(self, host, user, password):
        self.host = host.rstrip("/")
        self.user = user
        self.password = password
        self.token = None

    def call(self, path, method="GET", body=None):
        data = None
        if body is not None:
            data = json.dumps(body).encode()
        request = urllib.request.Request(self.host + path, data=data, method=method)
        request.add_header("Accept", "application/json")
        if data is not None:
            request.add_header("Content-Type", "application/json")
        if self.token:
            request.add_header("Authorization", "Bearer " + self.token)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                raw = response.read()
                return response.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            raw = error.read()
            try:
                parsed = json.loads(raw) if raw else None
            except json.JSONDecodeError:
                parsed = raw.decode("utf-8", "replace")
            return error.code, parsed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--search", default="Beethoven Symphony No. 9")
    args = parser.parse_args()

    client = Client(args.host, args.user, args.password)

    status, payload = client.call("/api/v0/session", "POST",
                                  {"username": args.user, "password": args.password})
    token = (payload or {}).get("token") if isinstance(payload, dict) else None
    check("POST /api/v0/session devolve token", status == 200 and bool(token), f"status={status}")
    if not token:
        return finish()
    client.token = token

    # --- servidor
    status, payload = client.call("/api/v0/server")
    check("GET /api/v0/server 200", status == 200, f"status={status}")
    payload = payload or {}
    for field in ("address", "ipEndPoint", "state"):
        check(f"server.{field} é string|nil", type_ok(payload.get(field), (str,)), repr(payload.get(field))[:40])
    for field in ("isConnected", "isConnecting", "isLoggedIn", "isLoggingIn", "isTransitioning"):
        check(f"server.{field} é bool|nil", type_ok(payload.get(field), (bool,)), repr(payload.get(field)))

    status, _ = client.call("/api/v0/server", "PUT", {"isConnected": True})
    check("PUT /api/v0/server {isConnected:true} aceito (idempotente)", status in (200, 204, 205), f"status={status}")

    # --- aplicação
    status, payload = client.call("/api/v0/application")
    check("GET /api/v0/application 200", status == 200, f"status={status}")
    payload = payload or {}
    version = payload.get("version") or {}
    check("application.version.full é string", isinstance(version.get("full"), str), repr(version.get("full"))[:40])
    user = payload.get("user") or {}
    check("application.user.username é string", isinstance(user.get("username"), str), repr(user.get("username"))[:40])
    privileges = user.get("privileges") or {}
    check("application.user.privileges.isPrivileged é bool",
          isinstance(privileges.get("isPrivileged"), bool))
    shares = payload.get("shares") or {}
    check("application.shares.directories é int", isinstance(shares.get("directories"), int), repr(shares.get("directories")))
    check("application.shares.files é int (ou ausente)", type_ok(shares.get("files"), (int,)), repr(shares.get("files")))
    distributed = payload.get("distributedNetwork") or {}
    check("application.distributedNetwork.branchLevel é int",
          isinstance(distributed.get("branchLevel"), int), repr(distributed.get("branchLevel")))
    check("application.distributedNetwork.hasParent é bool (ou ausente)",
          type_ok(distributed.get("hasParent"), (bool,)), repr(distributed.get("hasParent")))
    check("application.pendingRestart é bool", isinstance(payload.get("pendingRestart"), bool),
          repr(payload.get("pendingRestart")))

    # --- transferências
    status, payload = client.call("/api/v0/transfers/downloads")
    check("GET /api/v0/transfers/downloads 200", status == 200, f"status={status}")
    check("downloads é lista", isinstance(payload, list))
    if isinstance(payload, list) and payload:
        group = payload[0]
        check("downloads[].username é string", isinstance(group.get("username"), str))
        check("downloads[].directories é lista", isinstance(group.get("directories"), list))
        directories = group.get("directories") or []
        if directories:
            directory = directories[0]
            check("directory.directory é string|nil", type_ok(directory.get("directory"), (str,)))
            check("directory.fileCount é int", isinstance(directory.get("fileCount"), int))
            check("directory.files é lista", isinstance(directory.get("files"), list))
            files = directory.get("files") or []
            if files:
                transfer = files[0]
                for field, kinds in (
                    ("id", (str,)), ("username", (str,)), ("filename", (str,)),
                    ("size", (int,)), ("bytesTransferred", (int,)), ("bytesRemaining", (int,)),
                    ("averageSpeed", (int, float)), ("percentComplete", (int, float)),
                    ("state", (str,)), ("direction", (str,)), ("attempts", (int,)),
                ):
                    check(f"transfer.{field} tipo esperado", type_ok(transfer.get(field), kinds),
                          repr(transfer.get(field))[:40])

    status, payload = client.call("/api/v0/transfers/uploads")
    check("GET /api/v0/transfers/uploads 200 e lista", status == 200 and isinstance(payload, list), f"status={status}")

    # --- busca
    status, payload = client.call("/api/v0/searches", "POST", {"searchText": args.search})
    check("POST /api/v0/searches 200", status == 200, f"status={status}")
    payload = payload or {}
    search_id = payload.get("id")
    check("search.id é string", isinstance(search_id, str), repr(search_id)[:40])
    check("search.state é string", isinstance(payload.get("state"), str), repr(payload.get("state")))

    if search_id:
        status, payload = client.call(f"/api/v0/searches/{search_id}?includeResponses=true")
        check("GET /api/v0/searches/{id}?includeResponses=true 200", status == 200, f"status={status}")
        payload = payload or {}
        # A busca leva alguns segundos para receber respostas dos peers.
        waited = 0
        while not (payload.get("responses") or []) and waited < 40:
            time.sleep(4)
            waited += 4
            _, payload = client.call(f"/api/v0/searches/{search_id}?includeResponses=true")
            payload = payload or {}
        check("search.fileCount é int", isinstance(payload.get("fileCount"), int), repr(payload.get("fileCount")))
        check("search.responses é lista", isinstance(payload.get("responses"), list))
        responses = payload.get("responses") or []
        check("busca recebeu resposta de peer", len(responses) > 0, f"respostas={len(responses)} após {waited}s")
        if responses:
            peer = responses[0]
            for field, kinds in (("token", (int,)), ("username", (str,)), ("hasFreeUploadSlot", (bool,)),
                                 ("queueLength", (int,)), ("uploadSpeed", (int,)), ("fileCount", (int,)),
                                 ("files", (list,))):
                check(f"response.{field} tipo esperado", type_ok(peer.get(field), kinds),
                      repr(peer.get(field))[:40])
            files = peer.get("files") or []
            if files:
                item = files[0]
                for field, kinds in (("filename", (str,)), ("size", (int,)), ("extension", (str,)),
                                     ("bitRate", (int,)), ("length", (int,)), ("isLocked", (bool,)),
                                     ("code", (int,))):
                    check(f"search file.{field} tipo esperado", type_ok(item.get(field), kinds),
                          repr(item.get(field))[:40])
        status, _ = client.call(f"/api/v0/searches/{search_id}", "DELETE")
        check("DELETE /api/v0/searches/{id} aceito", status in (200, 204, 404), f"status={status}")

    # --- validação de rotas de escrita (probes inofensivos)
    status, payload = client.call("/api/v0/transfers/downloads/nao-existe", "POST", [])
    check("POST enqueue com lista vazia responde 400 (rota e corpo corretos)",
          status == 400 and "file" in str(payload).lower(), f"status={status} body={str(payload)[:60]}")

    status, payload = client.call("/api/v0/transfers/downloads/nao-existe", "POST",
                                  [{"filename": "pasta\\teste.mp3", "size": 1234}])
    check("POST enqueue com [{filename,size}] desserializa e chega ao peer (offline)",
          status in (500, 404) and "offline" in str(payload).lower(),
          f"status={status} body={str(payload)[:80]}")

    status, _ = client.call("/api/v0/transfers/downloads/nao-existe/nao-existe", "DELETE")
    check("DELETE transferência inexistente responde 400 (rota correta)", status == 400, f"status={status}")

    status, payload = client.call("/api/v0/conversations")
    check("GET /api/v0/conversations 200 e lista", status == 200 and isinstance(payload, list), f"status={status}")

    return finish()


def finish():
    failed = [r for r in results if r[0] == FAIL]
    print(f"\n{len(results) - len(failed)}/{len(results)} verificações passaram")
    if failed:
        print("falhas:")
        for _, name, detail in failed:
            print("  -", name, detail)
        return 1
    print("contrato compatível com os modelos do app")
    return 0


if __name__ == "__main__":
    sys.exit(main())
