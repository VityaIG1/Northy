#!/usr/bin/env python3
"""
North VPN — Mobileprovision generator for Ad-Hoc / Self-Signed deployment
Generates a valid DER-encoded CMS signed .mobileprovision profile.
"""

import sys
import os
import plistlib
import subprocess
from datetime import datetime, timezone, timedelta

def generate_profile(app_id: str, team_id: str, app_group: str, cert_pem: str, key_pem: str, output_path: str):
    now = datetime.now(timezone.utc)
    expiration = now + timedelta(days=3650) # 10 years validity

    profile_dict = {
        'AppIDName': f'North VPN ({app_id})',
        'ApplicationIdentifierPrefix': [team_id],
        'CreationDate': now,
        'ExpirationDate': expiration,
        'Name': f'North VPN AdHoc Profile ({app_id})',
        'TeamIdentifier': [team_id],
        'TeamName': 'North Security Team',
        'TimeToLive': 3650,
        'ProvisionsAllDevices': True,
        'Entitlements': {
            'application-identifier': f'{team_id}.{app_id}',
            'com.apple.developer.networking.networkextension': ['packet-tunnel-provider'],
            'com.apple.security.application-groups': [app_group],
            'get-task-allow': True
        }
    }

    temp_plist = f'{output_path}.raw.plist'
    with open(temp_plist, 'wb') as f:
        plistlib.dump(profile_dict, f)

    cmd = [
        'openssl', 'smime', '-sign',
        '-in', temp_plist,
        '-out', output_path,
        '-signer', cert_pem,
        '-inkey', key_pem,
        '-outform', 'DER',
        '-nodetach'
    ]
    try:
        subprocess.check_call(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f"Generated mobileprovision profile: {output_path} ({os.path.getsize(output_path)} bytes)")
    finally:
        if os.path.exists(temp_plist):
            os.remove(temp_plist)

if __name__ == '__main__':
    if len(sys.argv) < 7:
        print("Usage: generate_provisioning.py <app_id> <team_id> <app_group> <cert_pem> <key_pem> <output_path>")
        sys.exit(1)

    app_id = sys.argv[1]
    team_id = sys.argv[2]
    app_group = sys.argv[3]
    cert_pem = sys.argv[4]
    key_pem = sys.argv[5]
    output_path = sys.argv[6]

    generate_profile(app_id, team_id, app_group, cert_pem, key_pem, output_path)
