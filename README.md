# Proyecto Práctico — Despliegue Cloud, Seguridad y Troubleshooting

Despliegue de una arquitectura distribuida en Kubernetes sobre AWS / Minikube con hardening de seguridad y resolución de fallas.

## Estructura

- `db.sql`: Script DDL con las tablas transaccionales (`venta`, `detalle_venta`, `promocion`, `promocion_producto`) y datos iniciales de promociones.
- `k8s/`: manifiestos de Kubernetes (namespace, ConfigMap, Secret, Deployment de la app, Service y Deployment/Service de SQL Server).
- `docs/troubleshooting-log.md`: bitácora de los escenarios de troubleshooting.

## Despliegue

```bash
# 1. Crear namespace y configuraciones
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-security-configmap.yaml
kubectl apply -f k8s/02-db-secret.yaml

# 2. Desplegar base de datos SQL Server
kubectl apply -f k8s/05-db-deployment.yaml

# 3. Inicializar DDL en SQL Server (una vez que el pod esté Running)
DB_POD=$(kubectl get pod -l app=db -n practica-s12 -o jsonpath="{.items[0].metadata.name}")
kubectl cp db.sql practica-s12/$DB_POD:/tmp/db.sql
kubectl exec $DB_POD -n practica-s12 -- /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P YourStrongPassword2026 -C -i /tmp/db.sql

# 4. Desplegar la aplicación y servicio
kubectl apply -f k8s/03-app-deployment.yaml
kubectl apply -f k8s/04-app-service.yaml

# 5. Monitorear despliegue
kubectl get pods -n practica-s12 -w
kubectl get svc app-service -n practica-s12
```

## Acceso en Minikube

El servicio `app-service` está configurado como `LoadBalancer` en el puerto `8085`. Para acceder a la aplicación en un entorno de desarrollo local con Minikube:

1. **Vía Minikube Service (Túnel automático):**
   ```bash
   minikube service app-service -n practica-s12
   ```
2. **Vía Port-Forward:**
   ```bash
   kubectl port-forward svc/app-service 8085:8085 -n practica-s12
   ```
   Luego abre tu navegador o cliente HTTP en: `http://localhost:8085/actuator/health` o `http://localhost:8085/swagger-ui.html`.

## Evidencias

1. `kubectl get pods -n practica-s12` mostrando Pods en estado `Running` (1/1).
2. `kubectl exec -it <pod> -n practica-s12 -- id` mostrando `uid=10001(10001) gid=10001(10001)`.
3. `kubectl logs -l app=app -n practica-s12` sin errores de inicio de base de datos ni promociones.
4. Petición HTTP exitosa al servicio de la aplicación.
