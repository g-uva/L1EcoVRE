"""Install-time override for jupyter-vre-workflow's source-building installer."""
import asyncio
import fcntl
import os
import signal
from pathlib import Path

from tornado import iostream, web
try:
    from jupyter_vre_workflow import handlers
except ModuleNotFoundError:
    handlers = None  # Users may not have installed the extension yet.


async def install(self):
    directory = Path.home() / '.bin'
    directory.mkdir(exist_ok=True)
    lock = (directory / 'telemetry-api.lock').open('w')
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        lock.close()
        raise web.HTTPError(409, reason='Another telemetry installation is running')
    process = None
    disconnected = False

    async def event(name, data):
        nonlocal disconnected
        if not disconnected:
            try:
                await self._write_event(name, data)
            except iostream.StreamClosedError:
                disconnected = True

    async def output():
        while True:
            line = await process.stdout.readline()
            if not line:
                return
            await event('log', {'step': 0, 'text': line.decode(errors='replace')})

    try:
        self.set_header('Content-Type', 'text/event-stream')
        self.set_header('Cache-Control', 'no-cache')
        self.set_header('X-Accel-Buffering', 'no')
        await event('progress', {'step': 0, 'label': 'Install prebuilt telemetry binaries', 'progress': 0})
        process = await asyncio.create_subprocess_exec(
            '/bin/bash', '/srv/telemetry-installer/install.sh',
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.STDOUT,
            start_new_session=True,
        )
        reader = asyncio.create_task(output())
        try:
            async with asyncio.timeout(600):
                while process.returncode is None:
                    try:
                        await asyncio.wait_for(process.wait(), 15)
                    except asyncio.TimeoutError:
                        await event('heartbeat', {'step': 0, 'label': 'Installing telemetry'})
                await reader
        finally:
            if process.returncode is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    await asyncio.wait_for(process.wait(), 5)
                except asyncio.TimeoutError:
                    os.killpg(process.pid, signal.SIGKILL)
                    await process.wait()
            if not reader.done():
                reader.cancel()
            await asyncio.gather(reader, return_exceptions=True)
        if process.returncode:
            await event('install-error', f'Installer exited with code {process.returncode}; see ~/.bin/telemetry-install.log')
        else:
            await event('progress', {'step': 0, 'label': 'Telemetry ready', 'progress': 100})
            await event('done', {})
    except TimeoutError:
        await event('install-error', 'Installer exceeded 10 minutes; see ~/.bin/telemetry-install.log')
    finally:
        lock.close()


# setup_handlers resolves this class at extension registration time.
if handlers is not None:
    handlers.MetricsInstallHandler.get = web.authenticated(install)
