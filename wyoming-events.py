#!/usr/bin/env python3
"""Controls the LEDs on the ReSpeaker 2mic HAT."""
import argparse
import asyncio
import logging
import time
import json
import sys
import uuid
from typing import cast
from functools import partial
from posixpath import join

import aiohttp

# Wyoming

from wyoming.error import Error
from wyoming.event import Event
from wyoming.server import AsyncEventHandler, AsyncServer
from wyoming.snd import Played
from wyoming.wake import Detection

_LOGGER = logging.getLogger()

DEVICE_LOOKUP_TEMPLATE = """
{% set devices = states | map(attribute='entity_id') | map('device_id') | unique | reject('eq',None) | list %}
{%- set ns = namespace(devices = []) %}
{%- for device in devices %}
  {%- set name = device_attr(device, "name") %}
  {%- set idents = device_attr(device, "identifiers") %}
  {% if idents|list|count > 0 %}
  {% if name and "wyoming" in idents|list|first %}
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

SLIM_PROTO_LOOKUP_TEMPLATE = """
{% set devices = states | map(attribute='entity_id') | map('device_id') | unique | reject('eq',None) | list %}
{%- set ns = namespace(devices = []) %}
{%- for device in devices %}
  {%- set name = device_attr(device, "name") %}
  {%- set idents = device_attr(device, "identifiers") %}
  {% if idents|list|count > 0 %}
  {% if name and ("music_assistant" in idents|list|first or "slimproto" in idents|list|first)%}
  {%- set entities = device_entities(device) | list %}
  {%- set data = {
  "id": device,
  "name": (idents|list|first)[1],
  } %}
  {%- if entities %}
    {%- set ns.devices = ns.devices + [ data ] %}
  {%- endif %}
  {%- endif %}
  {%- endif %}
{%- endfor %}
{{ ns.devices }}
"""

SLIM_PROTO_CURRENT_VOL_TEMPLATE = '{{ {"vol": state_attr(device_entities("{DEVICE_ID}") | list | first, "volume_level") | float(-1)} }}'

def get_mac_address() -> str:
    """Return MAC address formatted as hex with no colons."""
    return "".join(
        # pylint: disable=consider-using-f-string
        ["{:02x}".format((uuid.getnode() >> ele) & 0xFF) for ele in range(0, 8 * 6, 8)][
            ::-1
        ]
    )

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
    parser.add_argument(
        "--disable-slimproto",
        action="store_true",
        help="Disable Slimproto control on certain events"
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
        self.slimproto_device = None
        self.slimproto_volume: float = -1
        self.mac = get_mac_address()

        _LOGGER.debug("Client connected: %s", self.client_id)

    async def async_send_ha_request(self, endpoint, body):
        """Send a request to the Home Assistant API."""
        async with aiohttp.ClientSession() as session:
            async with session.post(
                url=join(
                    self.cli_args.hass_url,
                    "api",
                    endpoint
                ),
                json=body,
                headers={
                    "Authorization": f"Bearer {self.cli_args.hass_token}",
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                }
            ) as req:
                return req

    async def async_request_template(self, template) -> dict|list:
        """Evaluate a template via the Home Assistant API."""
        req = await self.async_send_ha_request(
            "template",
            body={
                "template": template
            })
        if req.ok:
            data = await req.text()
            _LOGGER.info("Template eval got response: %s", data)
            return json.loads(str(data).replace("'", "\""))
        else:
            _LOGGER.error("Template eval request failed %s", req.status)
        return

    async def async_retrieve_device_id(self):
        """Returns and stores the device ID."""
        data: list[dict[str, str]] = await self.async_request_template(DEVICE_LOOKUP_TEMPLATE)
        if not isinstance(data, list):
            return
        filtered = [x for x in data if x["name"] == self.wyoming_name]
        if len(filtered) > 0:
            self.device_id = filtered[0]
            _LOGGER.info("Initialized with device %s", self.device_id)
            return
        _LOGGER.warning("Unable to find a device matching this satellite.")
        return

    async def async_retrieve_slimproto_device(self):
        """Returns and stores the Slimproto device info."""
        data: list[dict[str, str]] = await self.async_request_template(SLIM_PROTO_LOOKUP_TEMPLATE)
        if not isinstance(data, list):
            return
        filtered = [x for x in data if x["name"] == self.mac]
        if len(filtered)>0:
            self.slimproto_device = filtered[0]["id"]
            _LOGGER.info("Initialized with slimproto %s", self.slimproto_device)
            return
        _LOGGER.warning("Unable to find a SlimProto device matching this node %s", self.mac)
        return

    async def async_fire_event(self, event_type: str, event_data: dict) -> str:
        """Fire event on Home Assistant event bus"""
        data = None
        req = await self.async_send_ha_request(
            join("events", event_type),
            body={
                "device": self.device_id,
                "data": event_data
            }
        )
        data = await req.json()
        return cast(str, data.get("message", "No message provided"))

    async def async_ha_service_call(self, domain, service, data):
        """Perform a service call."""
        await self.async_send_ha_request(
            join("services", domain, service),
            data
        )

    async def async_slim_vol_duck(self):
        """Duck the volume of the SlimProto player."""
        if self.slimproto_device is None:
            return
        if self.slimproto_volume < 0.15:
            return
        await self.async_ha_service_call(
            domain="media_player",
            service="volume_set",
            data={
                "volume_level": self.slimproto_volume - (self.slimproto_volume * 20 / 100),
                "device_id": self.slimproto_device
            }
        )

    async def async_slim_vol_restore(self):
        """Restore the volume level."""
        if self.slimproto_device is None:
            return
        if self.slimproto_volume is None:
            return
        await self.async_ha_service_call(
            domain="media_player",
            service="volume_set",
            data={
                "volume_level": self.slimproto_volume,
                "device_id": self.slimproto_device
            }
        )

    async def handle_event(self, event: Event) -> bool:
        """Handle an event from Wyoming."""
        _LOGGER.debug(event)

        try:
            if self.device_id == "":
                await self.async_retrieve_device_id()
        except Exception as exc:
            _LOGGER.error("Error: %s", exc)

        try:
            if not self.cli_args.disable_slimproto and self.slimproto_device is None:
                await self.async_retrieve_slimproto_device()
            if not self.cli_args.disable_slimproto and self.slimproto_device is not None:
                if Detection.is_type(event):
                    self.slimproto_volume = await self.async_request_template(
                        SLIM_PROTO_CURRENT_VOL_TEMPLATE.format(DEVICE_ID=self.slimproto_device))
                    _LOGGER.debug("SlimProto device %s current volume %s",
                                  self.slimproto_device,
                                  self.slimproto_volume)
                    await self.async_slim_vol_duck()
                elif Played.is_type(event) or Error.is_type(event):
                    _LOGGER.debug("Restoring SlimProto device volume")
                    await self.async_slim_vol_restore()
        except Exception as exc:
            _LOGGER.error("SlimProto Error: %s", exc)

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
