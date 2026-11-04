{{- define "generic-cdi-plugin.labels" -}}
app.kubernetes.io/name: {{ .Release.Name }}
{{- end }}
