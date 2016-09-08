{%- if 'monitor_master' in salt['grains.get']('roles', []) + salt['pillar.get']('roles', []) %}

{%- from 'graphite/settings.sls' import graphite with context %}

install-deps:
  pkg.installed:
    - names:
      - memcached
      - python-pip
      - nginx
      - gcc
{%- if grains['os_family'] == 'Debian' %}
      - python-mysqldb
      - python-dev
      - sqlite3
      - libcairo2
      - libcairo2-dev
      - python-cairo
      - pkg-config
      - gunicorn
      - graphite-carbon
      - graphite-web
{%- elif grains['os_family'] == 'RedHat' %}
      - MySQL-python
      - python-devel
      - sqlite
      - bitmap
{%- if grains['os'] != 'Amazon' %}
      - bitmap-fonts-compat
{%- endif %}
      - pycairo-devel
      - pkgconfig
      - python-gunicorn
{%- endif %}

{%- if grains['os'] == 'Amazon' %}
{%- set pkg_list = ['fixed-fonts', 'console-fonts', 'fangsongti-fonts', 'lucida-typewriter-fonts', 'miscfixed-fonts', 'fonts-compat'] %}
{%- for fontpkg in pkg_list %}
install-{{ fontpkg }}-on-amazon:
  pkg.installed:
    - sources:
      - bitmap-{{ fontpkg }}: http://mirror.centos.org/centos/6/os/x86_64/Packages/bitmap-{{ fontpkg }}-0.3-15.el6.noarch.rpm
{%- endfor %}
{%- endif %}

#/tmp/graphite_reqs.txt:
#  file.managed:
#    - source: salt://graphite/files/graphite_reqs.txt
#    - template: jinja
#    - context:
#      graphite_version: '0.9.12'

#install-graphite-apps:
#  cmd.run:
#    - name: pip install -r /tmp/graphite_reqs.txt
#    - unless: test -d /opt/graphite/webapp
#    - require:
#      - file: /tmp/graphite_reqs.txt
#      - pkg: install-deps

/etc/graphite/local_settings.py:
  file.append:
    - text: SECRET_KEY = '2lk1j25l2h61234l6h123l6kh1263l21kh3621lk23h1213kl6j2'

{{ graphite.whisper_dir }}:
  file.directory:
    - user: _graphite
    - group: _graphite
    - makedirs: True
    - recurse:
      - user
      - group

{%- if graphite.whisper_dir != graphite.prefix + '/storage/whisper' %}

{{ graphite.prefix + '/storage/whisper' }}:
  file.symlink:
    - target: {{ graphite.whisper_dir }}
    - force: True

{%- endif %}

local-dirs:
  file.directory:
    - user: _graphite
    - group: _graphite
    - names:
      - /var/run/gunicorn-graphite
      - /var/log/gunicorn-graphite
#      - /var/run/carbon
#      - /var/log/carbon

#/opt/graphite/webapp/graphite/local_settings.py:
#  file.managed:
#    - source: salt://graphite/files/local_settings.py
#    - template: jinja
#    - context:
#      dbtype: {{ graphite.dbtype }}
#      dbname: {{ graphite.dbname }}
#      dbuser: {{ graphite.dbuser }}
#      dbpassword: {{ graphite.dbpassword }}
#      dbhost: {{ graphite.dbhost }}
#      dbport: {{ graphite.dbport }}

# django database fixtures
#{{ graphite.prefix }}/webapp/graphite/initial_data.yaml:
#  file.managed:
#    - source: salt://graphite/files/initial_data.yaml
#    - template: jinja
#    - context:
#      admin_email: {{ graphite.admin_email }}
#      admin_user: {{ graphite.admin_user }}
#      admin_password: {{ graphite.admin_password }}

#/etc/carbon/storage-schemas.conf:
#  file.managed:
#    - source: salt://graphite/files/storage-schemas.conf
#
#/etc/carbon/storage-aggregation.conf:
#  file.managed:
#    - source: salt://graphite/files/storage-aggregation.conf
#
#/etc/carbon/carbon.conf:
#  file.managed:
#    - source: salt://graphite/files/carbon.conf
#    - template: jinja
#    - context:
#      graphite_port: {{ graphite.port }}
#      graphite_pickle_port: {{ graphite.pickle_port }}
#      max_creates_per_minute: {{ graphite.max_creates_per_minute }}
#      max_updates_per_second: {{ graphite.max_updates_per_second }}

{%- if graphite.dbtype == 'sqlite3' %}
initialize-graphite-db-sqlite3:
  cmd.run:
    - name:  graphite-manage syncdb --noinput
{%- endif %}

#/etc/supervisor/conf.d/graphite.conf:
#  file.managed:
#    - source: salt://graphite/files/supervisord-graphite.conf
#    - mode: 644

## cannot get any watch construct to work
#restart-supervisor-for-graphite:
#  cmd.wait:
#    - name: service {# {{ graphite.supervisor_init_name }} #} restart
#    - watch:
#      - file: /etc/supervisor/conf.d/graphite.conf

/etc/nginx/conf.d/graphite.conf:
  file.managed:
    - source: salt://graphite/files/graphite.conf.nginx
    - template: jinja
    - context:
      graphite_host: {{ graphite.host }}

nginx:
  service.running:
    - enable: True
    - reload: True
    - watch:
      - file: /etc/nginx/conf.d/graphite.conf

carbon-service:
  service:
    - name: carbon-cache
    - running
    - reload: True
    - enable: True

{%- endif %}
