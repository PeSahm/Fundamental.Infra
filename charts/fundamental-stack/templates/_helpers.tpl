{{/*
=============================================================================
Fundamental Stack - Template Helpers
=============================================================================
This file contains helper templates (partials) used across the chart.
Following Helm best practices for DRY (Don't Repeat Yourself) principles.

For .NET Developers:
- Think of these as "extension methods" or "utility classes" in C#
- They generate reusable YAML snippets
- Called with: {{ include "fundamental-stack.labelname" . }}
=============================================================================
*/}}

{{/*
Expand the name of the chart.
Similar to: string GetChartName() => Release.Name ?? Chart.Name;
*/}}
{{- define "fundamental-stack.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this.
Similar to: string GetFullName() => $"{Release.Name}-{Chart.Name}".Substring(0, 63);
*/}}
{{- define "fundamental-stack.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "fundamental-stack.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
=============================================================================
Backend-specific helpers
=============================================================================
*/}}

{{- define "fundamental-stack.backend.name" -}}
{{- printf "%s-backend" (include "fundamental-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fundamental-stack.backend.fullname" -}}
{{- printf "%s-backend" (include "fundamental-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Backend selector labels - used in both Deployment and Service
*/}}
{{- define "fundamental-stack.backend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fundamental-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: backend
{{- end }}

{{/*
Backend common labels
*/}}
{{- define "fundamental-stack.backend.labels" -}}
helm.sh/chart: {{ include "fundamental-stack.chart" . }}
{{ include "fundamental-stack.backend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: fundamental-stack
{{- end }}

{{/*
=============================================================================
Frontend-specific helpers
=============================================================================
*/}}

{{- define "fundamental-stack.frontend.name" -}}
{{- printf "%s-frontend" (include "fundamental-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fundamental-stack.frontend.fullname" -}}
{{- printf "%s-frontend" (include "fundamental-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Frontend selector labels
*/}}
{{- define "fundamental-stack.frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "fundamental-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: frontend
{{- end }}

{{/*
Frontend common labels
*/}}
{{- define "fundamental-stack.frontend.labels" -}}
helm.sh/chart: {{ include "fundamental-stack.chart" . }}
{{ include "fundamental-stack.frontend.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: fundamental-stack
{{- end }}

{{/*
=============================================================================
Migrator-specific helpers
=============================================================================
*/}}

{{- define "fundamental-stack.migrator.name" -}}
{{- printf "%s-migrator" (include "fundamental-stack.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "fundamental-stack.migrator.labels" -}}
helm.sh/chart: {{ include "fundamental-stack.chart" . }}
app.kubernetes.io/name: {{ include "fundamental-stack.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: migrator
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: fundamental-stack
{{- end }}

{{/*
=============================================================================
Common helpers
=============================================================================
*/}}

{{/*
Create the name of the service account to use
*/}}
{{- define "fundamental-stack.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "fundamental-stack.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Generate image pull secret name
*/}}
{{- define "fundamental-stack.imagePullSecretName" -}}
{{- if .Values.global.imagePullSecrets }}
{{- first .Values.global.imagePullSecrets }}
{{- else }}
{{- printf "%s-registry-credentials" (include "fundamental-stack.fullname" .) }}
{{- end }}
{{- end }}

{{/*
=============================================================================
Database connection helpers
=============================================================================
*/}}

{{/*
PostgreSQL host - handles both internal and external
*/}}
{{- define "fundamental-stack.postgresql.host" -}}
{{- if .Values.postgresql.enabled }}
{{- printf "%s-postgresql" (include "fundamental-stack.fullname" .) }}
{{- else }}
{{- .Values.externalDatabase.host }}
{{- end }}
{{- end }}

{{/*
PostgreSQL port
*/}}
{{- define "fundamental-stack.postgresql.port" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.primary.service.ports.postgresql | default 5432 }}
{{- else }}
{{- .Values.externalDatabase.port | default 5432 }}
{{- end }}
{{- end }}

{{/*
PostgreSQL database name
*/}}
{{- define "fundamental-stack.postgresql.database" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.database | default "fundamental" }}
{{- else }}
{{- .Values.externalDatabase.database | default "fundamental" }}
{{- end }}
{{- end }}

{{/*
PostgreSQL secret name for credentials
*/}}
{{- define "fundamental-stack.postgresql.secretName" -}}
{{- if .Values.postgresql.enabled }}
{{- if .Values.postgresql.auth.existingSecret }}
{{- .Values.postgresql.auth.existingSecret }}
{{- else }}
{{- printf "%s-postgresql" (include "fundamental-stack.fullname" .) }}
{{- end }}
{{- else }}
{{- .Values.externalDatabase.existingSecret | default (printf "%s-external-db" (include "fundamental-stack.fullname" .)) }}
{{- end }}
{{- end }}

{{/*
PostgreSQL password key in secret
*/}}
{{- define "fundamental-stack.postgresql.passwordKey" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.secretKeys.userPasswordKey | default "password" }}
{{- else }}
{{- .Values.externalDatabase.existingSecretPasswordKey | default "password" }}
{{- end }}
{{- end }}

{{/*
=============================================================================
Redis connection helpers
=============================================================================
*/}}

{{/*
Redis host
*/}}
{{- define "fundamental-stack.redis.host" -}}
{{- if .Values.redis.enabled }}
{{- printf "%s-redis-master" (include "fundamental-stack.fullname" .) }}
{{- else }}
{{- .Values.externalRedis.host }}
{{- end }}
{{- end }}

{{/*
Redis port
*/}}
{{- define "fundamental-stack.redis.port" -}}
{{- if .Values.redis.enabled }}
{{- .Values.redis.master.service.ports.redis | default 6379 }}
{{- else }}
{{- .Values.externalRedis.port | default 6379 }}
{{- end }}
{{- end }}

{{/*
Redis secret name
*/}}
{{- define "fundamental-stack.redis.secretName" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.auth.existingSecret }}
{{- .Values.redis.auth.existingSecret }}
{{- else }}
{{- printf "%s-redis" (include "fundamental-stack.fullname" .) }}
{{- end }}
{{- else }}
{{- .Values.externalRedis.existingSecret | default (printf "%s-external-redis" (include "fundamental-stack.fullname" .)) }}
{{- end }}
{{- end }}

{{/*
=============================================================================
Security Context helpers (2025 Best Practices)
=============================================================================
These ensure pods run with minimal privileges following the principle of
least privilege. Required for production deployments.
*/}}

{{/*
Default pod security context - applies to all containers in the pod
*/}}
{{- define "fundamental-stack.podSecurityContext" -}}
runAsUser: 1000
runAsGroup: 3000
fsGroup: 2000
runAsNonRoot: true
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/*
Default container security context - applies per container
*/}}
{{- define "fundamental-stack.containerSecurityContext" -}}
allowPrivilegeEscalation: false
readOnlyRootFilesystem: true
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 3000
capabilities:
  drop:
    - ALL
seccompProfile:
  type: RuntimeDefault
{{- end }}

{{/*
=============================================================================
Probe helpers for Zero-Downtime Deployments
=============================================================================
*/}}

{{/*
Backend startup probe - critical for .NET cold starts
.NET applications need longer startup times, especially with EF Core migrations
*/}}
{{- define "fundamental-stack.backend.startupProbe" -}}
startupProbe:
  httpGet:
    path: {{ .Values.backend.probes.startup.path | default "/health/startup" }}
    port: http
  initialDelaySeconds: {{ .Values.backend.probes.startup.initialDelaySeconds | default 10 }}
  periodSeconds: {{ .Values.backend.probes.startup.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.backend.probes.startup.timeoutSeconds | default 5 }}
  failureThreshold: {{ .Values.backend.probes.startup.failureThreshold | default 30 }}
  successThreshold: 1
{{- end }}

{{/*
Backend liveness probe - restart if unhealthy
*/}}
{{- define "fundamental-stack.backend.livenessProbe" -}}
livenessProbe:
  httpGet:
    path: {{ .Values.backend.probes.liveness.path | default "/health/live" }}
    port: http
  initialDelaySeconds: {{ .Values.backend.probes.liveness.initialDelaySeconds | default 0 }}
  periodSeconds: {{ .Values.backend.probes.liveness.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.backend.probes.liveness.timeoutSeconds | default 5 }}
  failureThreshold: {{ .Values.backend.probes.liveness.failureThreshold | default 3 }}
  successThreshold: 1
{{- end }}

{{/*
Backend readiness probe - remove from service if not ready
*/}}
{{- define "fundamental-stack.backend.readinessProbe" -}}
readinessProbe:
  httpGet:
    path: {{ .Values.backend.probes.readiness.path | default "/health/ready" }}
    port: http
  initialDelaySeconds: {{ .Values.backend.probes.readiness.initialDelaySeconds | default 5 }}
  periodSeconds: {{ .Values.backend.probes.readiness.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.backend.probes.readiness.timeoutSeconds | default 3 }}
  failureThreshold: {{ .Values.backend.probes.readiness.failureThreshold | default 3 }}
  successThreshold: 1
{{- end }}

{{/*
Frontend startup probe
*/}}
{{- define "fundamental-stack.frontend.startupProbe" -}}
startupProbe:
  httpGet:
    path: {{ .Values.frontend.probes.startup.path | default "/" }}
    port: http
  initialDelaySeconds: {{ .Values.frontend.probes.startup.initialDelaySeconds | default 5 }}
  periodSeconds: {{ .Values.frontend.probes.startup.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.frontend.probes.startup.timeoutSeconds | default 3 }}
  failureThreshold: {{ .Values.frontend.probes.startup.failureThreshold | default 12 }}
  successThreshold: 1
{{- end }}

{{/*
Frontend liveness probe
*/}}
{{- define "fundamental-stack.frontend.livenessProbe" -}}
livenessProbe:
  httpGet:
    path: {{ .Values.frontend.probes.liveness.path | default "/" }}
    port: http
  initialDelaySeconds: {{ .Values.frontend.probes.liveness.initialDelaySeconds | default 0 }}
  periodSeconds: {{ .Values.frontend.probes.liveness.periodSeconds | default 10 }}
  timeoutSeconds: {{ .Values.frontend.probes.liveness.timeoutSeconds | default 3 }}
  failureThreshold: {{ .Values.frontend.probes.liveness.failureThreshold | default 3 }}
  successThreshold: 1
{{- end }}

{{/*
Frontend readiness probe
*/}}
{{- define "fundamental-stack.frontend.readinessProbe" -}}
readinessProbe:
  httpGet:
    path: {{ .Values.frontend.probes.readiness.path | default "/" }}
    port: http
  initialDelaySeconds: {{ .Values.frontend.probes.readiness.initialDelaySeconds | default 5 }}
  periodSeconds: {{ .Values.frontend.probes.readiness.periodSeconds | default 5 }}
  timeoutSeconds: {{ .Values.frontend.probes.readiness.timeoutSeconds | default 3 }}
  failureThreshold: {{ .Values.frontend.probes.readiness.failureThreshold | default 3 }}
  successThreshold: 1
{{- end }}

{{/*
=============================================================================
Connection string builder for .NET
=============================================================================
*/}}
{{- define "fundamental-stack.connectionString" -}}
Host={{ include "fundamental-stack.postgresql.host" . }};Port={{ include "fundamental-stack.postgresql.port" . }};Database={{ include "fundamental-stack.postgresql.database" . }};Username=$(DB_USERNAME);Password=$(DB_PASSWORD);
{{- end }}
