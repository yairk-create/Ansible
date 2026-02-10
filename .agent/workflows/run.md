---
description: Run an Ansible playbook with environment setup
---
1. Set locale and activate virtual environment
2. Run the playbook

Command:
```bash
export LC_ALL=C.utf8 && export LANG=C.utf8 && source venv/bin/activate && ansible-playbook playbooks/[playbook_name].yml -i inventory/hosts.ini [options]
```

// turbo
Example usage:
```bash
export LC_ALL=C.utf8 && export LANG=C.utf8 && source venv/bin/activate && ansible-playbook playbooks/zabbix.yml -i inventory/hosts.ini --check --diff
```
