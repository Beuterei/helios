{{- define "volume-backup.labels" -}}
app.kubernetes.io/name: volume-backup
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
