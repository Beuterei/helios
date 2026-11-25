{{- define "home-assistant.labels" -}}
app.kubernetes.io/name: home-assistant
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* ConfigMap keys cannot hold a slash, so nested paths use a double underscore. */}}
{{- define "home-assistant.fileKey" -}}
{{- . | replace "/" "__" -}}
{{- end }}
