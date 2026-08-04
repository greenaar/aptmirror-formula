{%- from 'aptmirror/map.jinja' import aptmirror, supported with context %}

{%- if supported %}
{%- if aptmirror.remove_distribution_package %}
aptmirror_distribution_package:
  pkg.removed:
    - name: {{ aptmirror.distribution_package }}
{%- endif %}

aptmirror_dependencies:
  pkg.installed:
    - pkgs: {{ aptmirror.dependency_packages|tojson }}
    {%- if aptmirror.remove_distribution_package %}
    - require:
      - pkg: aptmirror_distribution_package
    {%- endif %}

aptmirror_group:
  group.present:
    - name: {{ aptmirror.user.group }}
    - system: true
    - require:
      - pkg: aptmirror_dependencies

aptmirror_user:
  user.present:
    - name: {{ aptmirror.user.name }}
    - gid: {{ aptmirror.user.group }}
    - home: {{ aptmirror.paths.base }}
    - shell: {{ aptmirror.user.shell }}
    - system: true
    - createhome: false
    - require:
      - group: aptmirror_group

aptmirror_script:
  file.managed:
    - name: {{ aptmirror.lookup.script }}
    - source: salt://aptmirror/files/apt-mirror
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: true
    - require:
      - pkg: aptmirror_dependencies

{%- else %}
aptmirror_unsupported_platform:
  test.fail_without_changes:
    - name: >-
        This aptmirror formula supports Debian 12/13 and Ubuntu
        22.04/24.04/26.04 only; detected
        {{ grains.get('osfinger', grains.get('os', 'unknown')) }}.
    - failhard: true
{%- endif %}

