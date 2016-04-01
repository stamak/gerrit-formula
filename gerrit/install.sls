# -*- coding: utf-8 -*-
# vim: ft=yaml

{% from "gerrit/map.jinja" import settings with context -%}
{% set gerrit_war_file = "gerrit-" ~ settings.package.version ~ ".war" -%}

install_jre:
  pkg.installed:
    - name: {{ settings.jre }}

install_git:
  pkg.installed:
    - name: git

user_{{ settings.user }}:
  user.present:
    - name: {{ settings.user }}

group_{{ settings.group }}:
  group.present:
    - name: {{ settings.group }}

{{ settings.base_directory }}/{{ settings.site_directory }}/etc:
  file.directory:
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

{{ settings.base_directory }}/{{ settings.site_directory }}/lib:
  file.directory:
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

{% for name, library in salt['pillar.get']('gerrit:libraries', {}).items() %}
{{ install_dir }}/{{ site_dir }}/lib/{{ name }}.jar:
  file.managed:
    - source: {{ library.source }}
    - source_hash: {{ library.source_hash }}
    - user: {{ user }}
    - group: {{ group }}
{% endfor %}

{{ settings.base_directory }}/{{ settings.site_directory }}/plugins:
  file.directory:
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

{% for name, plugin in salt['pillar.get']('gerrit:plugins', {}).items() %}
{{ install_dir }}/{{ site_dir }}/plugins/{{ name }}.jar:
  file.managed:
    - source: {{ plugin.source }}
    - source_hash: {{ plugin.source_hash }}
    - user: {{ user }}
    - group: {{ group }}
{% endfor %}

gerrit_war:
  cmd.run:
    - name: wget -qO {{ settings.base_directory }}/{{ gerrit_war_file }} {{ settings.package.base_url }}/{{ gerrit_war_file }}
    - cwd: {{ settings.base_directory }}
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - unless: test -f {{ settings.base_directory }}/{{ gerrit_war_file }}

{{ settings.base_directory }}/{{ settings.site_directory }}/etc/gerrit.config:
  file.managed:
    - source: salt://gerrit/files/gerrit.config
    - template: jinja
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - mode: 0755
    - makedirs: true

{{ settings.base_directory }}/{{ settings.site_directory }}/etc/secure.config:
  file.managed:
    - source: salt://gerrit/files/secure.config
    - template: jinja
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - makedirs: true

/etc/default/gerritcodereview:
  file.managed:
    - contents: GERRIT_SITE={{ settings.base_directory }}/{{ settings.site_directory }}
    - user: root
    - group: root
    - mode: 0755

gerrit_init:
  cmd.run:
    - name: |
{% if settings.core_plugins is not none %}
    {% for plugin in settings.core_plugins %}
        java -jar {{ settings.base_directory }}/{{ gerrit_war_file }} init --batch --install-plugin {{ plugin }} -d {{ settings.base_directory }}/{{ settings.site_directory }}
    {% endfor %}
{% else %}
        java -jar {{ settings.base_directory }}/{{ gerrit_war_file }} init --batch -d {{ settings.base_directory }}/{{ settings.site_directory }}
{% endif %}
        java -jar {{ settings.base_directory }}/{{ gerrit_war_file }} reindex -d {{ settings.base_directory }}/{{ settings.site_directory }}
    - user: {{ settings.user }}
    - group: {{ settings.group }}
    - cwd: {{ settings.base_directory }}
    - unless: test -d {{ settings.base_directory }}/{{ settings.site_directory }}/bin

link_logs_to_var_log_gerrit:
  file.symlink:
    - name: /var/log/gerrit
    - target: {{ settings.base_directory }}/{{ settings.site_directory }}/logs
    - user: root
    - group: root

gerrit_init_script:
  file.symlink:
    - name: /etc/init.d/{{ settings.service }}
    - target: {{ settings.base_directory }}/{{ settings.site_directory }}/bin/gerrit.sh
    - user: root
    - group: root

{{ settings.service }}:
  service.running:
    - enable: true
    - watch:
      - file: {{ settings.base_directory }}/{{ settings.site_directory }}/etc/gerrit.config
