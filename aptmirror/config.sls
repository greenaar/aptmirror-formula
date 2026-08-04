{%- from 'aptmirror/map.jinja' import aptmirror, supported with context %}

include:
  - aptmirror.install

{%- if supported %}
{%- for path in [aptmirror.paths.base, aptmirror.paths.mirror, aptmirror.paths.skel, aptmirror.paths.var] %}
aptmirror_directory_{{ loop.index }}:
  file.directory:
    - name: {{ path }}
    - user: {{ aptmirror.user.name }}
    - group: {{ aptmirror.user.group }}
    - mode: '0755'
    - makedirs: true
    - require:
      - user: aptmirror_user
{%- endfor %}

aptmirror_config_directory:
  file.directory:
    - name: {{ aptmirror.lookup.config_dir }}
    - user: root
    - group: {{ aptmirror.user.group }}
    - mode: '0750'
    - makedirs: true
    - require:
      - group: aptmirror_group

aptmirror_config:
  file.managed:
    - name: {{ aptmirror.lookup.config }}
    - source: salt://aptmirror/files/mirror.list.jinja
    - template: jinja
    - context:
        aptmirror: {{ aptmirror|tojson }}
    - user: root
    - group: {{ aptmirror.user.group }}
    - mode: '0640'
    - require:
      - file: aptmirror_config_directory
      {%- for number in range(1, 5) %}
      - file: aptmirror_directory_{{ number }}
      {%- endfor %}

{%- if aptmirror.postmirror.enabled %}
aptmirror_postmirror_script:
  file.managed:
    - name: {{ aptmirror.paths.postmirror_script }}
    {%- if aptmirror.postmirror.contents_pillar %}
    - contents_pillar: {{ aptmirror.postmirror.contents_pillar }}
    {%- elif aptmirror.postmirror.contents is not none %}
    - contents: {{ aptmirror.postmirror.contents|yaml_encode }}
    {%- else %}
    - source: {{ aptmirror.postmirror.source }}
    - template: {{ aptmirror.postmirror.template }}
    - context: {{ aptmirror.postmirror.context|tojson }}
    {%- endif %}
    - user: {{ aptmirror.user.name }}
    - group: {{ aptmirror.user.group }}
    - mode: '0750'
    - require:
      - file: aptmirror_directory_4
{%- endif %}
{%- endif %}
