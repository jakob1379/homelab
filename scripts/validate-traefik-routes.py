#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
DYN_DIR = ROOT / "config" / "traefik" / "dyn"
STARTUP_RETRY = "startup-retry@file"
SABLIER_URL = "http://sablier:10000"
COMPOSE_ENTRYPOINTS = ("docker-compose.yml", "docker-compose.pods.yml")
EXPECTED_FILE_PROVIDER_TARGETS = {
    "anythingllm": ["http://anythingllm:3001/"],
    "bentopdf": ["http://bentopdf:8080/"],
    "cbeaver": ["http://cloudbeaver:8978/"],
    "dumbassets": ["http://dumbassets:3000/"],
    "ha": ["http://host.docker.internal:8123/"],
    "home": ["http://home:3000/"],
    "immich-power-tools": ["http://immich-power-tools:3000/"],
    "ittools": ["http://ittools:80/"],
    "keep": ["http://keep:3000/"],
    "listmonk": ["http://listmonk:9000/"],
    "netalertx": ["http://host.docker.internal:20211/"],
    "omni-tools": ["http://omni-tools:80/"],
    "paperless": ["http://paperless-web:8000/"],
    "rustfs-api": ["http://rustfs:9000/"],
    "rustfs-console": ["http://rustfs:9001/"],
    "seerr": ["http://seerr:5055/"],
    "speedtest": ["http://speedtest-tracker:80/"],
    "vert": ["http://vert:80/"],
    "whoami": ["http://whoami/"],
}
EXPECTED_DOCKER_LABEL_PORTS = {
    "adguard": "80",
    "bazarr": "6767",
    "dockhand": "3000",
    "immich": "2283",
    "jellyfin": "8096",
    "prowlarr": "9696",
    "radarr": "7878",
    "sonarr": "8989",
    "torrent": "8080",
    "traefik": "8080",
}


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open() as handle:
        return yaml.safe_load(handle) or {}


def as_label_map(labels: list[str] | dict[str, str] | None) -> dict[str, str]:
    if labels is None:
        return {}
    if isinstance(labels, dict):
        return {str(key): str(value) for key, value in labels.items()}

    result: dict[str, str] = {}
    for label in labels:
        key, separator, value = str(label).partition("=")
        if separator:
            result[key] = value
    return result


def active_service_paths() -> list[Path]:
    paths: list[Path] = []
    for entrypoint in COMPOSE_ENTRYPOINTS:
        for include in load_yaml(ROOT / entrypoint).get("include", []):
            if isinstance(include, str) and include.startswith("services/"):
                paths.append(ROOT / include)
    return sorted(paths)


def sablier_groups_from_services() -> dict[str, str]:
    groups: dict[str, str] = {}
    for path in active_service_paths():
        services = load_yaml(path).get("services", {})
        for name, service in services.items():
            labels = as_label_map(service.get("labels"))
            if labels.get("sablier.enable") == "true":
                group = labels.get("sablier.group")
                if not group:
                    raise AssertionError(f"{path}: {name} enables Sablier without sablier.group")
                groups[group] = f"{path.relative_to(ROOT)}:{name}"
    return groups


def file_provider_targets() -> dict[str, list[str]]:
    targets: dict[str, list[str]] = {}
    for path in sorted(DYN_DIR.glob("*.yml")):
        config = load_yaml(path).get("http", {})
        routers = config.get("routers", {})
        services = config.get("services", {})

        for router_name, router in routers.items():
            service_name = router.get("service", router_name)
            if service_name not in services:
                raise AssertionError(f"{path}: router {router_name} references missing service")

        for service_name, service in services.items():
            load_balancer = service.get("loadBalancer", {})
            servers = load_balancer.get("servers", [])
            urls = [server.get("url") for server in servers]
            if not urls or any(url is None for url in urls):
                raise AssertionError(f"{path}: service {service_name} has no server URLs")
            targets[service_name] = [str(url) for url in urls]
    return targets


def docker_label_ports() -> dict[str, str]:
    ports: dict[str, str] = {}
    prefix = "traefik.http.services."
    suffix = ".loadbalancer.server.port"

    for path in active_service_paths():
        services = load_yaml(path).get("services", {})
        for name, service in services.items():
            labels = as_label_map(service.get("labels"))
            for key, value in labels.items():
                if key.startswith(prefix) and key.endswith(suffix):
                    traefik_service = key.removeprefix(prefix).removesuffix(suffix)
                    ports[traefik_service] = value
                    if not value.isdigit():
                        raise AssertionError(
                            f"{path}: {name} has non-numeric Traefik port for {traefik_service}"
                        )
    return ports


def sablier_routes() -> dict[str, str]:
    groups: dict[str, str] = {}
    for path in sorted(DYN_DIR.glob("*.yml")):
        config = load_yaml(path).get("http", {})
        routers = config.get("routers", {})
        middlewares = config.get("middlewares", {})

        for router_name, router in routers.items():
            router_middlewares = router.get("middlewares", [])
            sablier_refs = [
                item for item in router_middlewares if str(item).startswith("sablier-")
            ]
            if not sablier_refs:
                continue
            if STARTUP_RETRY not in router_middlewares:
                raise AssertionError(
                    f"{path}: router {router_name} uses Sablier without {STARTUP_RETRY}"
                )

            for ref in sablier_refs:
                middleware_name = ref.removesuffix("@file")
                middleware = middlewares.get(middleware_name)
                if middleware is None and middleware_name == "sablier-default":
                    middleware = load_yaml(DYN_DIR / "common.yml")["http"]["middlewares"][
                        middleware_name
                    ]
                if middleware is None:
                    raise AssertionError(
                        f"{path}: router {router_name} references missing {ref}"
                    )

                plugin = middleware.get("plugin", {}).get("sablier")
                if not plugin:
                    raise AssertionError(f"{path}: {middleware_name} is not a Sablier plugin")
                if plugin.get("sablierUrl") != SABLIER_URL:
                    raise AssertionError(f"{path}: {middleware_name} has wrong sablierUrl")
                if not plugin.get("sessionDuration"):
                    raise AssertionError(f"{path}: {middleware_name} lacks sessionDuration")

                group = plugin.get("group")
                if not group:
                    raise AssertionError(f"{path}: {middleware_name} lacks group")
                groups[group] = f"{path.relative_to(ROOT)}:{router_name}"
    return groups


def main() -> int:
    expected_groups = sablier_groups_from_services()
    routed_groups = sablier_routes()
    actual_file_provider_targets = file_provider_targets()
    actual_docker_label_ports = docker_label_ports()

    missing = {
        group: owner
        for group, owner in expected_groups.items()
        if group not in routed_groups
    }
    if missing:
        details = "\n".join(
            f"  - {group}: declared by {owner}" for group, owner in sorted(missing.items())
        )
        raise AssertionError(f"Sablier groups without matching Traefik routes:\n{details}")

    if actual_file_provider_targets != EXPECTED_FILE_PROVIDER_TARGETS:
        raise AssertionError(
            "File-provider Traefik targets changed:\n"
            f"expected: {EXPECTED_FILE_PROVIDER_TARGETS}\n"
            f"actual:   {actual_file_provider_targets}"
        )

    if actual_docker_label_ports != EXPECTED_DOCKER_LABEL_PORTS:
        raise AssertionError(
            "Docker-label Traefik load-balancer ports changed:\n"
            f"expected: {EXPECTED_DOCKER_LABEL_PORTS}\n"
            f"actual:   {actual_docker_label_ports}"
        )

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
