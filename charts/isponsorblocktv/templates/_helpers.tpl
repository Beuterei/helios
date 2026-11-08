{{- define "isponsorblocktv.labels" -}}
app.kubernetes.io/name: isponsorblocktv
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
