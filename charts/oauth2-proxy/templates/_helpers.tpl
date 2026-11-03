{{- define "oauth2-proxy.labels" -}}
app.kubernetes.io/name: oauth2-proxy
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
