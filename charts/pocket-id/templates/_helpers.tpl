{{- define "pocket-id.labels" -}}
app.kubernetes.io/name: pocket-id
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
