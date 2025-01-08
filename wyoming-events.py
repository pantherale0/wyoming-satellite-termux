#!/usr/bin/env python3
"""Controls the LEDs on the ReSpeaker 2mic HAT."""
import argparse
import asyncio
import logging
import time
import json
import sys
from typing import cast
from functools import partial
from posixpath import join

import aiohttp

# Wyoming

from wyoming.event import Event
from wyoming.server import AsyncEventHandler, AsyncServer

_LOGGER = logging.getLogger()

DEVICE_LOOKUP_TEMPLATE = """
{% set devices = states | map(attribute='entity_id') | map('device_id') | unique | reject('eq',None) | list %}
{%- set ns = namespace(devices = []) %}
{%- for device in devices %}
  {%- set name = device_attr(device, "name") %}
  {%- set idents = device_attr(device, "identifiers") %}
  {% if idents|list|count > 0 %}
  {% if name and " - " in name and "wyoming" in idents|list|first %}
  {%- set entities = device_entities(device) | list %}
  {%- set data = {
  "id": device,
  "name": name,
  } %}
  {%- if entities %}
    {%- set ns.devices = ns.devices + [ data ] %}
  {%- endif %}
  {%- endif %}
  {%- endif %}
{%- endfor %}
{{ ns.devices }}"""

async def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--uri", required=True, help="unix:// or tcp://")
    parser.add_argument("--hass-token", required=True, help="Longlived access token from HASS")
    parser.add_argument("--wyoming-name", required=True, help="The name of the Wyoming device")
    parser.add_argument(
        "--hass-url",
        required=False,
        help="URL to Home Assistant instance",
        default="http://homeassistant.local:8123"
    )
    parser.add_argument("--debug", action="store_true", help="Log DEBUG messages")
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)
    _LOGGER.debug(args)

    _LOGGER.info("Ready")

    # Start server
    server = AsyncServer.from_uri(args.uri)

    try:
        await server.run(partial(WyomingEventHandler, args))
    except KeyboardInterrupt:
        pass

class WyomingEventHandler(AsyncEventHandler):
    """Generic Wyoming event handler."""

    def __init__(
        self,
        cli_args: argparse.Namespace,
        *args,
        **kwargs,
    ) -> None:
        super().__init__(*args, **kwargs)
        self.cli_args = cli_args
        self.client_id = str(time.monotonic_ns())
        self.wyoming_name = cli_args.wyoming_name
        self.device_id = ""

        _LOGGER.debug("Client connected: %s", self.client_id)

    async def async_retrieve_device_id(self):
        """Returns and stores the device ID."""
        async with aiohttp.ClientSession() as session:
            async with session.post(
                url=join(
                    self.cli_args.hass_url,
                    "api",
                    "template"
                ),
                json={
                    "template": DEVICE_LOOKUP_TEMPLATE
                },
                headers={
                    "Authorization": f"Bearer {self.cli_args.hass_token}",
                    "Content-Type": "application/json",
                }
            ) as req:
                if req.ok:
                    data = await req.text()
                    _LOGGER.info("Got response: %s", data)
                    data: list[dict[str, str]] = json.loads(data)
                    if not isinstance(data, list):
                        return
                    filtered = [x for x in data if x == self.wyoming_name]
                    if len(filtered) > 0:
                        self.device_id = filtered[0]
                        _LOGGER.info("Initialized with device %s", self.device_id)
                        return
                    _LOGGER.warning("Unable to find a device matching this satellite.")
                    return
                else:
                    _LOGGER.error("Device lookup request failed %s", req.status)
                return

    async def async_fire_event(self, event_type: str, event_data: dict) -> str:
        """Fire event on Home Assistant event bus"""
        data = None
        async with aiohttp.ClientSession() as session:
            async with session.post(
                url=join(
                    f"{self.cli_args.hass_url}/api",
                    "events",
                    event_type
                ),
                json={
                    **event_data,
                    "device": self.device_id
                },
                headers={
                    "Authorization": f"Bearer {self.cli_args.hass_token}",
                    "Content-Type": "application/json",
                }
            ) as req:
                data = await req.json()
        return cast(str, data.get("message", "No message provided"))

    async def handle_event(self, event: Event) -> bool:
        """Handle an event from Wyoming."""
        _LOGGER.debug(event)

        try:
            if self.device_id == "":
                await self.async_retrieve_device_id()
        except Exception as exc:
            _LOGGER.error("Error: %s", exc)

        try:
            # Forward a Wyoming event to Home Assistant
            await self.async_fire_event(
                event_type=f"wyoming_{event.type.lower()}",
                event_data=event.data
            )
        except Exception as exc:
            _LOGGER.error("Error broadcasting event: %s", exc)

        return True

if __name__ == "__main__":
    try:
        root = logging.getLogger()
        root.setLevel(logging.DEBUG)

        handler = logging.StreamHandler(sys.stdout)
        handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        root.addHandler(handler)
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
