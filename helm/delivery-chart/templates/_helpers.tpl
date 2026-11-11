{{/*
Базовое имя чарта
*/}}
{{- define "delivery-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Полное имя объекта на основе имени релиза (предотвращает конфликты при повторной установке)
*/}}
{{- define "delivery-chart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Общие метки чарта
*/}}
{{- define "delivery-chart.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{ include "delivery-chart.selectorLabels" . }}
app.kubernetes.io/version: {{ .Values.image.tag | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Метки селектора для API
*/}}
{{- define "delivery-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "delivery-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}