#!/usr/bin/env python3
import requests
import json
import sys

# Configuration
URL = "http://192.168.1.210:8080/api_jsonrpc.php"
USER = "yair"
PASS = "L0cal1t8"
TRUENAS_IPS = {
    "192.168.1.203": "truenas1",
    "192.168.1.242": "truenas2"
}
SNMP_COMMUNITY = "public"
TEMPLATE_NAME = "TrueNAS SCALE 22.12.1 and up by SNMP"

def zabbix_request(method, params, token=None):
    payload = {
        "jsonrpc": "2.0",
        "method": method,
        "params": params,
        "id": 1
    }
    if token:
        payload["auth"] = token
    
    response = requests.post(URL, json=payload)
    return response.json()

def main():
    # 1. Login
    login = zabbix_request("user.login", {"username": USER, "password": PASS})
    if "error" in login:
        print(f"Login failed: {login['error']}")
        sys.exit(1)
    token = login["result"]

    # 2. Get Template ID
    template = zabbix_request("template.get", {"filter": {"host": [TEMPLATE_NAME]}, "output": ["templateid"]}, token)
    if not template["result"]:
        print(f"Template '{TEMPLATE_NAME}' not found!")
        sys.exit(1)
    template_id = template["result"][0]["templateid"]

    # 3. Process each host by IP
    for ip, friendly_name in TRUENAS_IPS.items():
        print(f"Configuring {friendly_name} ({ip})...")
        
        # Find Host by Interface IP
        host_interface = zabbix_request("hostinterface.get", {
            "filter": {"ip": [ip]},
            "output": ["hostid"]
        }, token)
        
        if not host_interface["result"]:
            print(f"No host found with IP {ip} in Zabbix. You may need to create it manually or via Ansible.")
            continue
            
        host_id = host_interface["result"][0]["hostid"]
        
        # Get current host details
        host_details = zabbix_request("host.get", {
            "hostids": [host_id],
            "output": ["host", "name"],
            "selectInterfaces": "extend"
        }, token)
        
        current_name = host_details["result"][0]["host"]
        interfaces = host_details["result"][0]["interfaces"]
        print(f" Found host: {current_name} (ID: {host_id})")

        # Rename to friendly name if it's currently an IP or different
        if current_name != friendly_name:
             print(f" Renaming {current_name} to {friendly_name}")
             zabbix_request("host.update", {"hostid": host_id, "host": friendly_name}, token)

        # Check if SNMP interface already exists
        snmp_interface = next((i for i in interfaces if i["type"] == "2" and i["port"] == "161"), None)
        
        if not snmp_interface:
            print(f" Adding SNMP interface...")
            zabbix_request("hostinterface.create", {
                "hostid": host_id,
                "main": 1,
                "type": 2, # SNMP
                "useip": 1,
                "ip": ip,
                "dns": "",
                "port": "161",
                "details": {
                    "version": 2,
                    "bulk": 1,
                    "community": "{$SNMP_COMMUNITY}"
                }
            }, token)
        else:
            print(f" SNMP interface already exists.")

        # 4. Link Template and set Macro
        print(f" Linking template and setting macro...")
        # Get existing templates to avoid overwriting
        existing_host = zabbix_request("host.get", {
            "hostids": [host_id],
            "selectParentTemplates": ["templateid"]
        }, token)
        
        tpls = [{"templateid": t["templateid"]} for t in existing_host["result"][0]["parentTemplates"]]
        if not any(t["templateid"] == template_id for t in tpls):
            tpls.append({"templateid": template_id})

        zabbix_request("host.update", {
            "hostid": host_id,
            "templates": tpls,
            "macros": [
                {
                    "macro": "{$SNMP_COMMUNITY}",
                    "value": SNMP_COMMUNITY
                }
            ]
        }, token)

    print("Zabbix SNMP configuration complete!")

if __name__ == "__main__":
    main()
