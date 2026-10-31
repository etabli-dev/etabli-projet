#!/usr/bin/env python3
"""Typecheck production Foundation code and exercise clients without real credentials."""
from pathlib import Path
import subprocess
import tempfile
root = Path(__file__).resolve().parents[1]
net = root / 'ios/App/Net'
files = [net / 'Client.swift', net / 'HttpTransport.swift']
if (net / 'HAL.swift').exists():
    files.append(net / 'HAL.swift')
subprocess.run(['swiftc', '-typecheck', *map(str, files), str(root / 'ios/App/Keychain.swift')], check=True)
subprocess.run(['swiftc', '-frontend', '-parse', *map(str, (root / 'ios').rglob('*.swift'))], check=True)
with tempfile.TemporaryDirectory(prefix='etabli-client-') as temporary:
    executable = str(Path(temporary) / 'check')
    subprocess.run(['swiftc', *map(str, files), str(root / 'scripts/ClientFixtures.swift'), str(root / 'scripts/check_client.swift'), '-o', executable], check=True)
    subprocess.run([executable], check=True)
