{{/* Expand the name of the chart. */}}
{{- define "contoso-fabric.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Fully qualified app name. */}}
{{- define "contoso-fabric.fullname" -}}
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

{{- define "contoso-fabric.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Labels applied to every object. */}}
{{- define "contoso-fabric.labels" -}}
helm.sh/chart: {{ include "contoso-fabric.chart" . }}
{{ include "contoso-fabric.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "contoso-fabric.selectorLabels" -}}
app.kubernetes.io/name: {{ include "contoso-fabric.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "contoso-fabric.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "contoso-fabric.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/* Build a fully-qualified image reference for a component. */}}
{{- define "contoso-fabric.image" -}}
{{- $root := index . 0 -}}
{{- $repository := index . 1 -}}
{{- printf "%s/%s:%s" $root.Values.image.registry $repository (toString $root.Values.image.tag) -}}
{{- end }}
