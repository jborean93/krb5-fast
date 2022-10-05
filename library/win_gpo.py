#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2022, Jordan Borean
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_gpo
short_description: Sets up a GPO.
description:
- Create a GPO object in the current or explicitly targeted domain.
options:
  name:
    description:
    - The name of the GPO to manage
    required: yes
    type: str
  state:
    description:
    - When C(yes), the GPO will be created.
    - When C(no), the GPO will be removed.
    choices:
    - absent
    - present
    default: present
    type: str
  comment:
    decription:
    - The comment for the GPO to set when creating.
    type: str
  domain:
    description:
    - The fully qualified domain name to search/create the GPO in.
    type: str
author:
- Jordan Borean (@jborean93)
'''

EXAMPLES = r'''
- name: create GPO
  win_gpo:
    name: test-gpo
    state: present

- name: remove the GPO
  win_gpo:
    name: test-gpo
    state: absent
'''

RETURN = r'''
'''

