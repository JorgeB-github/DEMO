# CI/CD delta - dataprev (Agentforce)

Automatización de despliegue **delta** para el proyecto `dataprev`, portada desde el
proyecto DEMO y adaptada a este entorno.

## Diferencias con DEMO

| Aspecto            | DEMO                     | dataprev                                   |
|--------------------|--------------------------|--------------------------------------------|
| Runner             | `ubuntu-latest`          | `group: gps-github-test-runners` (pago)    |
| Rama base          | `main`                   | `dev`                                       |
| Ambiente destino   | `AgentForce`             | `qa` (PR y push)                            |
| Secret JWT         | `JWT_AGENTFORCE`         | `JWT_DataPrev` (key file `dataprev.key`)   |
| Alias de org       | `ci`                     | `qa`                                        |
| Render por ambiente| no aplica                | `render-agents.sh` con `RENDER_ENV=qa`     |
| TZ release notes   | Buenos Aires             | `America/Sao_Paulo`                         |

`vars.CLIENT_ID`, `vars.INSTANCE_URL` y `vars.USERNAME` se toman del environment `qa`.

## Workflows

- `.github/workflows/dev-pr-validate-delta.yaml`
  - Trigger: **Pull Request** hacia `dev`.
  - `MODE=validate`: deploy check-only (`--dry-run`) de metadata + `sf agent validate authoring-bundle`.
- `.github/workflows/dev-push-deploy-delta.yaml`
  - Trigger: **push/merge** a `dev`.
  - `MODE=deploy`: deploy de metadata + `sf agent publish authoring-bundle` + `sf agent activate`.
  - Genera/actualiza `docs/release-notes.csv` y lo commitea de vuelta a `dev` (`[skip ci]`).

> Estos workflows corren **en paralelo** a los existentes (`DevOnPush.yaml`, `DevOnPr.yaml`).
> Para evitar dobles despliegues en `dev`, deshabilitá o eliminá los viejos antes de usar estos.

## Flujo del script `agent-delta.sh`

1. Calcula el delta con `sfdx-git-delta` entre `FROM_REF` y `TO_REF`.
2. Detecta agentes cambiados (`aiAuthoringBundles/<Agente>/`) desde `git diff` y los separa
   del `package.xml` con `split-package.js`.
3. Si `RENDER_ENV` está definido, renderiza **solo los agentes cambiados**
   (`render-agents.sh` con `ONLY_AGENTS`): reemplaza `@@AGENT_USER@@` y `@@RAG_CONFIG_ID@@`
   por los valores `*.qa` de `agentPipeline/<Agente>.env`.
4. Apex: si cambió una clase no-test, busca su test por convención
   (`<Clase>Test`, `Test<Clase>`, ...), lo suma al package (`add-members.js`) y corre
   `--test-level RunSpecifiedTests`. Si no hay tests, `NoTestRun`.
5. Metadata clásica → `sf project deploy start`. Agentes → Agentforce DX (publish/activate).
6. (deploy) `release-notes.js` agrega una fila por componente al CSV.

## Prerrequisitos en GitHub (environment `qa`)

- Secret `JWT_DataPrev` (clave privada del Connected App usado para JWT).
- Variables `CLIENT_ID`, `INSTANCE_URL`, `USERNAME`.
- El Connected App debe tener el scope **`api`** (Manage user data via APIs); sin él,
  `sf agent publish/activate` falla con *"This session is not valid for use with the REST API"*.

## Datos por-ambiente de agentes (`agentPipeline/*.env`)

Cada agente publicado por esta automatización debe tener valores `qa` en su `.env`:

```
name=GovBRMDSAgent
username.qa=...
adl.config.faq.id.qa=...   # o adl.config.id.qa
```

> Hoy los `.env` traen `username=` (plano) y `adl.config.*.qa=`. `render-agents.sh`
> espera `username.<env>=` (p.ej. `username.qa=`). Verificá que existan las claves por
> ambiente para los agentes que vayas a publicar.

## Nota importante: genAiPlannerBundles

Este repo versiona también `genAiPlannerBundles/` (salida compilada del agente). Esta
automatización maneja los **agentes vía Agentforce DX** (`aiAuthoringBundles`), pero los
`genAiPlannerBundles` que cambien **se deployarían como metadata clásica** y podrían
chocar con el `publish`. Recomendación: no commitear `genAiPlannerBundles` (se regeneran
con el publish) o pedir que los excluyamos del delta. Avisá si querés que los filtre.
