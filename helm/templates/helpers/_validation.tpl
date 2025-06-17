{{/*
    Validation helper templates
*/}}

{{- define "validate.target" -}}
    {{- if not (or (eq .Values.deployment.target "openshift") (eq .Values.deployment.target "podman")) }}
        {{- fail "Error: .deployment.target must be one of 'openshift' or 'podman'." }}
    {{- end }}
{{- end }}

{{- define "validate.layout" -}}
    {{- if not (or .Values.layout .Values.layout_name) }}
        {{- fail "Error: One of .layout or .layout_name must not be empty." }}
    {{- end }}
{{- end }}

{{- define "validate.openshift" -}}
    {{- if eq .Values.deployment.target "openshift" }}
        {{- if not .Values.deployment.namespace }}
            {{- fail "Error: .deployment.namespace must not be empty." }}
        {{- end }}
        {{- if not .Values.deployment.serviceAccountName }}
            {{- fail "Error: .deployment.serviceAccountName must not be empty." }}
        {{- end }}
    {{- end }}
{{- end }}

{{- define "validate.all" -}}
    {{- include "validate.target" . }}
    {{- include "validate.layout" . }}
    {{- include "validate.openshift" . }}
{{- end }}