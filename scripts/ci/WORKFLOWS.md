# CI/CD delta - Workflows y scripts (dataprev / Agentforce)

Guía paso a paso de los **dos workflows** de GitHub Actions del proyecto y de **qué hace
cada script** de `scripts/ci/`.

- **PR → `dev`**: valida el cambio (check-only, no toca la org).
- **Push/merge → `dev`**: despliega y activa el cambio en la org de QA.

Ambos workflows corren el **mismo script** (`agent-delta.sh`); lo único que cambia es la
variable `MODE` (`validate` vs `deploy`) y unas pocas variables extra.

---

## 1. Workflow de PR: `dev-pr-validate-delta.yaml`

**Nombre:** `PR to dev - Validate QA (delta)`
**Se dispara:** al abrir/actualizar un **Pull Request hacia `dev`**.
**Objetivo:** validar que la metadata y los agentes del cambio son correctos, **sin
desplegar ni activar nada** en la org.

### Entorno
- Runner del grupo pago `gps-github-test-runners`.
- Container Docker con Salesforce CLI (`tnascimento013/latam_salesforcedx_industries_orgdevmodebuilds:latest`).
- Environment `qa` de GitHub (de ahí salen los secrets/vars).

### Pasos
1. **Checkout (full history)** — clona el repo con **todo el historial** (`fetch-depth: 0`),
   necesario porque el delta se calcula con `git diff` entre commits.
2. **Mark workspace as safe for git** — evita el error de git *dubious ownership* dentro del container.
3. **Check agent tokens** — ejecuta `check-agent-tokens.sh` sobre los `.agent` cambiados del PR
   y **falla** si `default_agent_user` o `rag_feature_config_id` traen valores reales de ambiente
   en lugar de los tokens `@@AGENT_USER@@` / `@@RAG_CONFIG_ID@@`. Corre temprano (antes del login),
   así el PR se rechaza rápido sin tocar la org.
4. **Check agent description lengths** — ejecuta `check-agent-desc-length.sh` sobre los `.agent`
   cambiados y **falla** si una `description` supera el límite del campo real en Salesforce
   (`subagent`/`start_agent` > 2000 → `GenAiPluginDefinition.Description`). Corre sin org, así se
   detecta el corte/fallo antes del `publish` (donde hoy explota) o del truncado silencioso por UI.
5. **Extract JWT private key** — vuelca el secret `JWT_DataPrev` al archivo `dataprev.key`.
6. **Install / update CLI plugins** — asegura `sfdx-git-delta` (arma el package delta) y
   `@salesforce/plugin-agent` (comandos `sf agent ...`).
7. **Authenticate (JWT)** — login no interactivo contra la org con alias `qa` (client id +
   `dataprev.key`).
8. **Validate delta (check-only)** — ejecuta `agent-delta.sh` con:
   - `FROM_REF` = `pull_request.base.sha` (base del PR)
   - `TO_REF`  = `pull_request.head.sha` (head del PR)
   - `MODE=validate`, `TARGET_ORG=qa`, `RENDER_ENV=qa`

### Resultado
Todo corre en dry-run + `sf agent validate`. **No se escribe nada en la org.** El PR queda
con el check en verde/rojo según la validación.

---

## 2. Workflow de Push: `dev-push-deploy-delta.yaml`

**Nombre:** `Push to dev - Deploy & Activate QA (delta)`
**Se dispara:** en **push/merge a `dev`**.
**Objetivo:** desplegar la metadata, **publicar y activar** los agentes cambiados, y registrar
las release notes.

### Entorno
Igual que el de PR (mismo runner, container y environment `qa`), más `permissions: contents: write`
(pensado para poder commitear las release notes; hoy ese commit está deshabilitado, ver más abajo).

### Pasos
1. **Checkout (full history)** — igual que en PR.
2. **Mark workspace as safe for git** — igual.
3. **Extract JWT private key** — igual.
4. **Install / update CLI plugins** — igual.
5. **Authenticate (JWT)** — igual (alias `qa`).
6. **Deploy delta + publish & activate agent** — ejecuta `agent-delta.sh` con:
   - Antes, calcula `PR_NUMBER` desde el mensaje del merge commit (`Merge pull request #N ...`).
   - `FROM_REF` = `github.event.before` (commit anterior en `dev`)
   - `TO_REF`  = `github.sha` (commit recién pusheado)
   - `MODE=deploy`, `TARGET_ORG=qa`, `RENDER_ENV=qa`
   - `RELEASE_NOTES=docs/release-notes.csv`, `PR_NUMBER=<n>`, `TZ_RN=America/Sao_Paulo`

### Nota sobre release notes
El step "Commit release notes" está **comentado/deshabilitado**: la rama `dev` está protegida
(requiere PR + status checks), así que el push directo del CI era rechazado (GH013). El CSV
se **sigue generando** en `docs/release-notes.csv` durante el deploy (queda en los logs), solo
que ya no se commitea a la rama. Para reactivarlo, descomentar ese step en el workflow.

### Resultado
Metadata desplegada, agentes publicados y activados en QA, y una fila por componente
registrada en el CSV de release notes.

---

## 3. Diferencia clave entre ambos workflows

| Aspecto            | PR (`validate`)                        | Push (`deploy`)                                  |
|--------------------|----------------------------------------|--------------------------------------------------|
| Trigger            | `pull_request` → `dev`                 | `push` → `dev`                                   |
| `MODE`             | `validate`                             | `deploy`                                         |
| `FROM_REF`/`TO_REF`| base/head del PR                       | `github.event.before` / `github.sha`            |
| Metadata           | `sf project deploy start --dry-run`    | `sf project deploy start` (real)                 |
| Agentes            | `sf agent validate authoring-bundle`   | `sf agent publish` + `activate` (+ concierge)    |
| Release notes      | no                                     | sí (`RELEASE_NOTES`, `PR_NUMBER`, `TZ_RN`)       |
| Toca la org        | **No**                                 | **Sí**                                           |

---

## 4. Qué hace cada script de `scripts/ci/`

### `agent-delta.sh` — orquestador principal
Es el corazón del CI; ambos workflows lo invocan. Según `MODE`:

1. Resuelve `FROM_REF` (si no es usable, cae a `TO_REF~1`).
2. Genera el **delta** con `sf sgd source delta` (sfdx-git-delta) → `delta/package/package.xml`.
3. Detecta **agentes cambiados** desde el `git diff` sobre `aiAuthoringBundles/<Agente>/`
   (más robusto que confiar solo en sgd, que puede no reconocer `AiAuthoringBundle`).
4. Separa agentes de la metadata clásica con `split-package.js` → `package-noagent.xml`.
5. Si `RENDER_ENV` está definido, renderiza **solo los agentes cambiados** con `render-agents.sh`.
6. Detecta clases Apex cambiadas y resuelve sus tests por convención; si hace falta los suma
   al package con `add-members.js` y arma `--test-level RunSpecifiedTests` (si no, `NoTestRun`).
7. **`validate`**: metadata → `sf project deploy start --dry-run`; agentes → `sf agent validate authoring-bundle`.
8. **`deploy`**: metadata → `sf project deploy start` (real); agentes → `sf agent publish` + `activate`.
   Orquesta además el **super agente concierge** (`CONCIERGE_AGENT`): lo desactiva antes de
   (re)publicar subagentes y lo reactiva al final, para que quede siempre activo.
9. **`deploy`**: registra release notes con `release-notes.js`.

**Variables de entorno principales:** `FROM_REF`, `TO_REF`, `MODE` (validate|deploy),
`TARGET_ORG` (requerida), `SOURCE_DIR` (default `force-app`), `RENDER_ENV`, `RELEASE_NOTES`,
`PR_NUMBER`, `TZ_RN`, `CONCIERGE_AGENT` (default `GovBRConciergeAgent`).

### `split-package.js` — separa agentes de la metadata
Toma el `package.xml` del delta y:
- Escribe una copia **sin** el bloque `<types>` de `AiAuthoringBundle` (los agentes van por
  Agentforce DX, no por deploy de metadata) → `package-noagent.xml`.
- Imprime por stdout los api-names de los agentes cambiados, para que el shell los recorra.

**Uso:** `node split-package.js <package.xml> <package-sin-agentes.xml>`

### `add-members.js` — inyecta miembros a un `package.xml`
Helper de texto que **agrega `<members>` a un `package.xml` ya existente** (deduplica y crea
el bloque `<types>` si falta). En este pipeline se usa para sumar las **clases de test de Apex**
descubiertas por convención, así se despliegan y se pueden correr con `RunSpecifiedTests`.

**Uso:** `node add-members.js <package.xml> <TypeName> <member> [<member> ...]`

### `render-agents.sh` — resuelve tokens por-ambiente en los `.agent`
Antes del deploy, sustituye en cada `.agent` los tokens por el valor del ambiente destino,
leyendo de `agentPipeline/<Agente>.env`:
- `@@AGENT_USER@@`    → `username.<env>`
- `@@RAG_CONFIG_ID@@` → `adl.config.faq.id.<env>` (o `adl.config.id.<env>` como fallback)

Solo exige/sustituye un token si el `.agent` realmente lo contiene. Reescribe archivos en el
workspace efímero del runner (nada se commitea). Con `ONLY_AGENTS` limita el render a los
agentes del cambio.

**Variables:** `TARGET_ENV` (requerida), `PIPELINE_DIR` (default `agentPipeline`),
`BUNDLES_DIR`, `DRY_RUN`, `ONLY_AGENTS`.

### `check-agent-tokens.sh` — guardrail de tokens en los `.agent`
Corre en el workflow de **PR** (antes del login). Revisa los `.agent` **cambiados** en el PR
(via `git diff FROM_REF..TO_REF`) y **falla** si alguna de estas claves trae un valor real de
ambiente en vez de su token:

- `default_agent_user:` debe ser `"@@AGENT_USER@@"`
- `rag_feature_config_id:` debe ser `"@@RAG_CONFIG_ID@@"`

Así se evita que un agente editado en una org de dev "pise" la config ambientable (los valores
por-ambiente los inyecta `render-agents.sh` en el runner, nunca se commitean). No exige que las
claves existan: un agente sin RAG puede no tener `rag_feature_config_id`.

**Uso:** `FROM_REF=<base> TO_REF=<head> bash check-agent-tokens.sh`
(o `CHECK_ALL=true bash check-agent-tokens.sh` para revisar todos los `.agent` localmente).

### `check-agent-desc-length.sh` + `check-agent-desc-length.js` — guardrail de longitud de `description`
Corre en el workflow de **PR** (antes del login, sin org). El `.sh` resuelve los `.agent`
**cambiados** (via `git diff FROM_REF..TO_REF`) y el `.js` parsea cada uno y mide las `description`
contra el límite del campo real en Salesforce:

- `config.description` → `BotDefinition.Description` (**≤ 1000**) → **ERROR**
  (el pipeline no recorta nada; si excede, `sf agent publish` falla y el desarrollador debe resumirla).
- `subagent`/`start_agent` `description` → `GenAiPluginDefinition.Description` (**≤ 2000**) → **ERROR**
  (nadie la recorta; es la que hace fallar `sf agent publish`).

Soporta cadena `"..."`, block scalar (`|`, `>`, `->`) y escalar plano. Mide la longitud cruda
(`\n` = 1) para el corte duro y avisa si con `<br>` (expansión al compilar) quedaría al borde.
Motivo: la `description` es de **ruteo** (corta); el comportamiento y los guardrails van en
`instructions` (límite alto).

**Uso:** `FROM_REF=<base> TO_REF=<head> bash check-agent-desc-length.sh`
(o `CHECK_ALL=true bash check-agent-desc-length.sh` para revisar todos los `.agent` localmente).
**Env:** `CONFIG_DESC_LIMIT` (1000), `SUBAGENT_DESC_LIMIT` (2000).

### `release-notes.js` — genera/actualiza las release notes
Al final del `deploy`, agrega al CSV acumulativo **una fila por componente desplegado**, con
columnas `PR, Fecha, Hora, Tipo, Componente`. Lee los componentes del `package.xml` y suma los
agentes aparte (que no están en el package porque van por Agentforce DX). Migra el CSV en sitio
si tiene el header viejo (sin columna `Hora`).

**Uso:** `node release-notes.js <package.xml|-> <pr> <date> <time> <csvPath> [agentName ...]`

---

## 5. Resumen en una línea

- **PR a `dev`** → checkout completo → login JWT a QA → `agent-delta.sh` (validate) → calcula
  delta, valida metadata en dry-run y valida bundles de agentes. **No toca la org.**
- **Push a `dev`** → mismos pasos previos → `agent-delta.sh` (deploy) → despliega metadata,
  publica/activa agentes (con orquestación del concierge) y registra release notes. **Toca la org.**

Cadena de scripts: `agent-delta.sh` orquesta; `split-package.js` + `add-members.js` preparan el
`package.xml`; `render-agents.sh` ambienta los `.agent`; `release-notes.js` documenta lo desplegado.

---

## 6. Notas relacionadas

- **Límites de longitud de campos del agente (pipeline vs UI):** ver
  [`docs/agentforce-field-limits.md`](../../docs/agentforce-field-limits.md).
  Explica por qué una descripción larga se guarda bien desde la UI pero falla al
  desplegar por pipeline (`BotDefinition.Description` tope 1000).
