# CI/CD Agentforce - Delta deploy

Pipeline basado en el diff de git para desplegar y activar agentes en cada PR/merge a `main`.

## Workflows

| Archivo | Disparador | Qué hace |
|---|---|---|
| `.github/workflows/pr-to-main.yaml` | PR hacia `main` | Calcula el delta y **valida** (check-only `--dry-run` + `sf agent validate`). No activa nada. |
| `.github/workflows/AgenForceAuto.yaml` | push/merge a `main` | Calcula el delta, **deploya** la metadata y **publica + activa** el agente. |

Ambos usan el script reutilizable `scripts/ci/agent-delta.sh`.

## Cómo funciona el delta

1. `sfdx-git-delta` compara `FROM_REF` (base) vs `TO_REF` (head) y genera `delta/package/package.xml`.
2. `scripts/ci/split-package.js` separa el `AiAuthoringBundle` del resto:
   - **Metadata** (Flow, PermissionSet, Apex, ...) -> `sf project deploy start --manifest`.
   - **Agentes** -> `sf agent publish authoring-bundle` + `sf agent activate`.
3. El orden garantiza que las dependencias (flows/permsets) existan antes de publicar el agente.

## Configuración requerida (GitHub → Settings → Environments → `AgentForce`)

**Secrets**
- `JWT_AGENTFORCE` — contenido del private key (`AgentForce.key`) para el JWT.

**Variables**
- `CLIENT_ID` — Consumer Key de la External Client App `AgentForceAPPDeploy`.
- `USERNAME` — usuario de integración (ej. `jbetasdev4@salesforce.com`).
- `INSTANCE_URL` — **dominio real** de la org: `https://login.salesforce.com` o `https://<tu-dominio>.my.salesforce.com`.
  - NO usar `*.salesforce-setup.com` (rompe el JWT).

## ⚠️ Blocker conocido (resolver antes de que el deploy funcione)

La External Client App `AgentForceAPPDeploy` debe tener el scope **`Api` ("Manage user data via APIs")**.
Hoy tiene `Basic, Web, RefreshToken, SFApiPlatform` — le falta `Api`, y por eso el deploy falla con
`This session is not valid for use with the REST API`.

Fix: Setup → External Client App Manager → `AgentForceAPPDeploy` → OAuth Settings → agregar
**Manage user data via APIs (api)** → Save → esperar 2-10 min.

## ⚠️ Seguridad

El repo tiene commiteados `AgentForce.key`, `AgentForce.crt`, `AgentForce.csr`.
El `.key` es la clave privada del JWT: **no debería estar en el repo**. Recomendado:
- Borrarlos del control de versiones y dejar solo el secret `JWT_AGENTFORCE`.
- Agregar `*.key`, `*.crt`, `*.csr` al `.gitignore`.

## Limitaciones actuales

- No maneja borrados (destructiveChanges). Si necesitás eliminar metadata, hay que extender el script
  para usar `delta/destructiveChanges/destructiveChanges.xml`.
