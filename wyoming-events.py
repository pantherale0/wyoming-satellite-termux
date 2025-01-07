#!/usr/bin/env python3
"""Controls the LEDs on the ReSpeaker 2mic HAT."""
import argparse
import asyncio
import logging
import time
from typing import cast
from functools import partial
from posixpath import join

import aiohttp

# Wyoming

from wyoming.event import Event
from wyoming.server import AsyncEventHandler, AsyncServer

_LOGGER = logging.getLogger()

async def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--uri", required=True, help="unix:// or tcp://")
    parser.add_argument("--hass-token", required=True, help="Longlived access token from HASS")
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

        _LOGGER.debug("Client connected: %s", self.client_id)

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
                json=event_data,
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

        # Forward a Wyoming event to Home Assistant
        await self.async_fire_event(
            event_type=f"wyoming_{event.type.lower()}",
            event_data=event.data
        )

        return True

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
