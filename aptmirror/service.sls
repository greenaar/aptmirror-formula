{%- from 'aptmirror/map.jinja' import aptmirror, supported with context %}

include:
  - aptmirror.install
  - aptmirror.config

{%- if supported %}
aptmirror_service_unit:
  file.managed:
    - name: {{ aptmirror.lookup.service_unit }}
    - source: salt://aptmirror/files/apt-mirror-sync.service.jinja
    - template: jinja
    - context:
        aptmirror: {{ aptmirror|tojson }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: aptmirror_script
      - file: aptmirror_config
      {%- if aptmirror.postmirror.enabled %}
      - file: aptmirror_postmirror_script
      {%- endif %}

aptmirror_timer_unit:
  file.managed:
    - name: {{ aptmirror.lookup.timer_unit }}
    - source: salt://aptmirror/files/apt-mirror-sync.timer.jinja
    - template: jinja
    - context:
        aptmirror: {{ aptmirror|tojson }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: aptmirror_service_unit

aptmirror_systemd_reload:
  module.run:
    - name: service.systemctl_reload
    - onchanges:
      - file: aptmirror_service_unit
      - file: aptmirror_timer_unit

aptmirror_timer:
  service.{{ 'running' if aptmirror.schedule.enabled else 'dead' }}:
    - name: {{ aptmirror.lookup.timer_service }}
    - enable: {{ aptmirror.schedule.enabled }}
    - require:
      - file: aptmirror_timer_unit
      - module: aptmirror_systemd_reload
{%- endif %}
