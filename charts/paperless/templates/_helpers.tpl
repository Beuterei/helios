{{- define "paperless.labels" -}}
app.kubernetes.io/name: paperless
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
