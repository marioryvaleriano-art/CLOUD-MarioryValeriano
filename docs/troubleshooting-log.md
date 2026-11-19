# Bitácora de Troubleshooting — practica-s12

## Escenario A — CrashLoopBackOff por mala inyección de variables

**Síntoma:** los Pods del Deployment `app` entran en `CrashLoopBackOff` a los pocos segundos de arrancar.

**Diagnóstico:** `kubectl logs <pod> -n practica-s12` muestra un error de autenticación contra la base de datos. Al revisar el Secret se confirma que los valores en Base64 se generaron con `echo "valor" | base64` (sin `-n`), por lo que incluyen un salto de línea al decodificarse y la contraseña queda inválida.

**Solución:** regenerar los valores con `echo -n "valor" | base64` y reaplicar el manifiesto con `kubectl apply -f k8s/02-db-secret.yaml`. Reiniciar el Deployment con `kubectl rollout restart deployment/app -n practica-s12`.

**Verificación:** `kubectl get pods -n practica-s12` muestra los Pods en `Running` y `kubectl exec` confirma que la variable llega limpia.

## Escenario B — Falla de conectividad backend ↔ base de datos

**Síntoma:** el backend arranca pero no logra conectarse al puerto interno del servicio de base de datos.

**Diagnóstico:** desde dentro del Pod, `nc -zv db-service 5432` (o `getent hosts db-service`) falla. Al revisar el Service de la base de datos se detecta que el `targetPort` no coincide con el puerto real del contenedor, y el `DB_HOST` del ConfigMap apuntaba a un nombre distinto al del Service.

**Solución:** corregir el `targetPort` del Service de la base de datos y alinear `DB_HOST` con el nombre exacto del Service (`db-service`), ambos en el namespace `practica-s12`.

**Verificación:** `nc -zv db-service 5432` responde exitoso desde el Pod del backend y los logs muestran la conexión establecida.

## Escenario C — Reinicios constantes por sondas mal configuradas

**Síntoma:** los Pods arrancan pero se reinician cada pocos segundos.

**Diagnóstico:** `kubectl describe pod <pod> -n practica-s12` reporta `Liveness probe failed: HTTP probe failed with statuscode: 404`. Las sondas apuntaban a rutas inexistentes en la aplicación.

**Solución:** corregir las rutas a `/actuator/health/liveness` y `/actuator/health/readiness`, y ajustar `initialDelaySeconds` para dar tiempo al arranque de la aplicación.

**Verificación:** la columna `RESTARTS` se mantiene en 0 y `kubectl describe` deja de mostrar eventos de fallo de sonda.

## Hardening aplicado

- `runAsNonRoot: true` y `runAsUser: 10001` a nivel de Pod y contenedor.
- `readOnlyRootFilesystem: true` con volumen `emptyDir` montado en `/tmp`.
- `allowPrivilegeEscalation: false` y `capabilities.drop: ["ALL"]`.
- Credenciales en un Secret con valores en Base64, inyectadas con `secretRef`.
- Validación con `kubectl exec -it <pod> -n practica-s12 -- id` mostrando `uid=10001`.
