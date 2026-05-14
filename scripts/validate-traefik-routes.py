#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import yaml


ROOT = Path(__file__).resolve().parents[1]
DYN_DIR = ROOT / "config" / "traefik" / "dyn"
SERVICES_DIR = ROOT / "services"
STARTUP_RETRY = "startup-retry@file"
SABLIER_URL = "http://sablier:10000"


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


def sablier_groups_from_services() -> dict[str, str]:
    groups: dict[str, str] = {}
    for path in sorted(SERVICES_DIR.rglob("*.yml")):
        services = load_yaml(path).get("services", {})
        for name, service in services.items():
            labels = as_label_map(service.get("labels"))
            if labels.get("sablier.enable") == "true":
                group = labels.get("sablier.group")
                if not group:
                    raise AssertionError(f"{path}: {name} enables Sablier without sablier.group")
                groups[group] = f"{path.relative_to(ROOT)}:{name}"
    return groups


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

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
