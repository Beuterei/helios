{{- define "norish.labels" -}}
app.kubernetes.io/name: norish
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
