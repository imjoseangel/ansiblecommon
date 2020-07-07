# Toolbox role

Different utilities for Windows and Linux

## Requirements

ansible >= 2.9.x

## Variables

None

## Dependencies

No direct dependencies.

## Example Playbook

eg:

```yaml
---
- name: Ansible
  hosts: localhost
  connection: local
  gather_facts: false

  tasks:

    - name: Include role
      include_role:
        name: imjoseangel.common.toolbox
        action_dummy: deploy
```

## License

MIT

## Author Information

imjoseangel
