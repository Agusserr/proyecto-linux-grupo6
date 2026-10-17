# proyecto-linux-grupo6

**Proyecto final de Introducción al Software Libre (ISL135)**

Universidad de El Salvador · Facultad Multidisciplinaria de Occidente · Departamento de Ingeniería y Arquitectura

Ingeniería en Desarrollo de Software / Educación en Línea · Ciclo II – 2026

Fecha de entrega: martes 3 de noviembre de 2026

---

## 1. Descripción y objetivo

Implementación de un **servidor Linux automatizado mediante contenedores Docker**, integrando administración de sistemas (usuarios, grupos y permisos), automatización y monitoreo con cron, control de versiones con Git/GitHub y virtualización con Docker (servidores web Nginx, imagen personalizada, redes y volúmenes).

Todo el trabajo se realizó siguiendo, en orden, cada requerimiento de la guía del proyecto (secciones 1 a 8) y sus entregables.

## 2. Integrantes y responsabilidades

| Integrante | Carnet | Secciones de la guía | Tema |
|---|---|---|---|
| Ángel Gustavo Serrano Benavides | SB22013 | 1 y 3 | Entorno base y control de versiones |
| Esmeralda Isabel Alvarez Rivas  | AR21036 | 2 y 4 | Docker base, script de monitoreo y cron |
| José Adalberto Díaz Lue         | DL25004 | 5 y 6 | Servidor web y Dockerfile |
| Paola Surgey Herecules Jirón    | HJ23002 | 7 y 8 | Redes, volúmenes y verificación final |

Cada integrante realiza sus commits desde su propio clon con su identidad de Git, de modo que el historial refleja la participación de los cuatro (ver sección 8).

## 3. Arquitectura implementada

### 3.1 Servicios y puertos

| Contenedor | Puerto del host | Imagen | Origen del contenido | Sección |
|---|---|---|---|---|
| `nginx-oficial` | 8080 | `nginx` | `/proyecto/web/` montado en `/usr/share/nginx/html/` | 5 |
| `nginx-personalizado` | 8081 | `servidor-grupo6` | `web/` copiado dentro de la imagen | 6 |
| `nginx-red` | 8082 | `nginx` | Página por defecto, conectado a `red-proyecto` | 7.1 |
| `nginx-volumen` | 8083 | `nginx` | Volumen `volumen-web` | 7.2 |
| `alpine-test` (temporal) | – | `alpine` | Prueba de `ping` en `red-proyecto` | 8.1 |

Recursos Docker: red `red-proyecto`, volumen `volumen-web`, imagen `servidor-grupo6`.

### 3.2 Usuarios y grupos

| Usuario | Grupos | Función |
|---|---|---|
| `adminsys` | `sudo`, `docker` | Administrador del sistema y dueño de `/proyecto` |
| `tecnico` | `soporte`, `docker` | Soporte técnico (archivos de configuración) |
| `visitante` | `web` | Acceso al contenido web |

### 3.3 Estructura de `/proyecto/` (este repositorio)

```
proyecto/
├── datos/        # archivos de configuración   (grupo soporte, setgid)
├── web/          # archivos del sitio web      (grupo web, setgid)
├── scripts/      # scripts de automatización
│   ├── reporte_sistema.sh
│   └── verificacion_final.sh
├── capturas/     # evidencias del proyecto
├── Dockerfile
├── .dockerignore
└── README.md
```

## 4. Entorno y convenciones

- **Máquina virtual:** Oracle VirtualBox con Linux Mint 22.3 (base Ubuntu 24.04 «noble»).
- **Número de grupo:** 6. Hostname `servidor-grupo6`, repositorio `proyecto-linux-grupo6`, imagen Docker `servidor-grupo6`.
- **Nombres en minúsculas y sin tilde.** La guía escribe «técnico» en la sección 1.1 y `tecnico` en la 4.1. Se usó **`tecnico`** porque Linux no admite tildes en nombres de usuario y es el nombre que usa la guía en los comandos de Docker.
- **Cuenta de trabajo:** `adminsys` (con sudo). Los comandos de Docker, cron y Git del servidor se ejecutan con esa cuenta (`sudo -iu adminsys`).
- **Saltos de línea:** los scripts se crean y editan en Linux (LF) para evitar el error `bad interpreter`.

---

## 5. Pasos de instalación y configuración

> **Orden de ejecución real:** 1 → 3 → 4 → 2 → 5 → 6 → 7 → 8. La sección 4 (Docker) se hizo antes que la 2 porque el script de monitoreo cuenta contenedores y el usuario del cron necesita acceso a Docker. La numeración de abajo sigue la guía del proyecto.

### Sección 1. Preparación del entorno servidor

#### 1.1 Administración básica del sistema

**Hostname `servidor-grupo6`:**

```bash
sudo hostnamectl set-hostname servidor-grupo6
sudo nano /etc/hosts        # dejar la línea: 127.0.1.1  servidor-grupo6
hostnamectl
hostname
```

**Tres usuarios** (`adminsys`, `tecnico`, `visitante`):

```bash
sudo adduser adminsys
sudo adduser tecnico
sudo adduser visitante
```

Los datos del campo de información personal (nombre completo, habitación, teléfonos y otro) se completaron con valores cortos. `chfn` rechazó los valores con «campos demasiado largos», por lo que el campo se llenó con `usermod -c`:

```bash
sudo usermod -c "Administrador,Grupo6,00000000,00000000,ISL135" adminsys
```

**Dos grupos** (`soporte` y `web`) y asignación de usuarios:

```bash
sudo groupadd soporte
sudo groupadd web

sudo usermod -aG sudo adminsys       # adminsys con privilegios de sudo
sudo usermod -aG soporte tecnico     # tecnico pertenece a soporte
sudo usermod -aG web visitante       # visitante pertenece a web
```

Se usa siempre `-aG` (con **a**): sin `-a`, `usermod -G` reemplaza los grupos suplementarios y podría quitar `sudo` a la cuenta.

**Verificación:**

```bash
id adminsys
id tecnico
id visitante
getent group sudo soporte web
getent passwd adminsys tecnico visitante
```

Resultado esperado: `adminsys` con el grupo `sudo`, `tecnico` con `soporte` y `visitante` con `web`.

#### 1.2 Estructura de directorios y permisos

```bash
sudo mkdir -p /proyecto/{datos,web,scripts,capturas}
sudo chown -R adminsys:adminsys /proyecto
sudo chgrp soporte /proyecto/datos        # datos/ pertenece al grupo soporte
sudo chgrp web /proyecto/web              # web/ pertenece al grupo web
sudo chmod 755 /proyecto
sudo chmod 2775 /proyecto/datos /proyecto/web
ls -ld /proyecto /proyecto/*
```

El modo `2775` activa el bit **setgid** (la `s` en los permisos del grupo): los archivos nuevos dentro de `datos/` y `web/` **heredan el grupo del directorio** y no el grupo primario de quien los crea. Además da escritura al grupo.

**Prueba de herencia de grupo:**

```bash
sudo -u tecnico touch /proyecto/datos/prueba_tecnico.txt
sudo -u visitante touch /proyecto/web/prueba_visitante.txt
ls -l /proyecto/datos /proyecto/web

# Limpiar las pruebas
sudo rm /proyecto/datos/prueba_tecnico.txt /proyecto/web/prueba_visitante.txt
```

Resultado esperado: `datos` como `drwxrwsr-x adminsys soporte`, `web` como `drwxrwsr-x adminsys web`; `prueba_tecnico.txt` con grupo `soporte` y `prueba_visitante.txt` con grupo `web`.

---

### Sección 3. Control de versiones

Repositorio Git local en `/proyecto/`, primer commit con toda la estructura y subida a GitHub (`proyecto-linux-grupo6`).

```bash
sudo -iu adminsys
sudo apt update && sudo apt install -y git
cd /proyecto
git init -b main
git config user.name "Ángel Gustavo Serrano Benavides"
git config user.email "sb22013@ues.edu.sv"
git config --global --add safe.directory /proyecto

# Git no sube directorios vacíos: se agrega un .gitkeep a cada uno
touch datos/.gitkeep web/.gitkeep scripts/.gitkeep capturas/.gitkeep

git add .
git commit -m "Primer commit: estructura del proyecto"
git log --oneline
git status
```

**Repositorio remoto en GitHub:** se creó el repositorio **vacío** `proyecto-linux-grupo6` (público, sin README, `.gitignore` ni licencia, para evitar conflictos). Para autenticar el servidor se generó una llave SSH y se registró como *Deploy key* con permiso de escritura (Settings → Deploy keys → Add deploy key → *Allow write access*).

```bash
ssh-keygen -t ed25519 -C "servidor-grupo6" -f ~/.ssh/id_ed25519 -N ""
cat ~/.ssh/id_ed25519.pub        # copiar la línea a GitHub

ssh -T git@github.com
git remote add origin git@github.com:Agusserr/proyecto-linux-grupo6.git
git push -u origin main
git remote -v
```

**README.md** (este archivo), creado después del primer commit:

```bash
cd /proyecto
git add README.md
git commit -m "Agrega README.md con descripcion y pasos de instalacion"
git push
```

**Colaboradores:** en GitHub, Settings → Collaborators → Add people, con los otros tres integrantes.

---

### Sección 4. Docker

#### 4.1 Instalación y configuración

Instalación de Docker Engine desde el repositorio oficial (los pasos pueden cambiar; referencia: <https://docs.docker.com/engine/install/ubuntu/>):

```bash
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

En Linux Mint se usa `UBUNTU_CODENAME` (valor `noble`) en lugar del nombre propio de Mint, porque el repositorio de Docker publica paquetes para Ubuntu.

**Habilitar e iniciar el servicio:**

```bash
sudo systemctl enable --now docker
systemctl status docker --no-pager
```

**Agregar `adminsys` y `tecnico` al grupo `docker`** (para usar Docker sin `sudo`):

```bash
sudo usermod -aG docker adminsys
sudo usermod -aG docker tecnico
getent group docker
```

**Verificar la instalación:**

```bash
docker --version
sudo -u adminsys docker ps
sudo -u tecnico docker ps
```

Resultado esperado: ambos usuarios ejecutan `docker ps` sin `sudo` y sin error de permisos. Si se usa una sesión abierta antes del cambio de grupo, hay que cerrar sesión y volver a entrar (o `newgrp docker`).

#### 4.2 Verificación inicial

```bash
docker run --name hello-test hello-world
docker images
docker ps -a
```

`hello-world` imprime su mensaje y termina, por eso aparece en `docker ps -a` con estado `Exited (0)`. Se le dio nombre (`hello-test`) para eliminarlo antes de la verificación final: `docker rm hello-test`.

---

### Sección 2. Automatización y monitoreo

#### 2.1 Script de monitoreo del sistema

Archivo `/proyecto/scripts/reporte_sistema.sh`:

```bash
#!/bin/bash
# reporte_sistema.sh - Reporte de estado del servidor
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

echo "=============================================="
echo " REPORTE DEL SISTEMA"
echo "=============================================="
echo "Fecha y hora          : $(date '+%Y-%m-%d %H:%M:%S')"
echo "Nombre del host       : $(hostname)"
echo "Usuarios conectados   : $(who | wc -l)"
echo "Espacio libre en /    : $(df -h / | awk 'NR==2 {print $4}')"
echo "Memoria RAM disponible: $(free -h | awk '/^Mem:/ {print $7}')"
if command -v docker >/dev/null 2>&1; then
  echo "Contenedores activos  : $(docker ps -q | wc -l)"
else
  echo "Contenedores activos  : docker no instalado"
fi
echo "----------------------------------------------"
```

Muestra los seis datos que pide la guía: fecha y hora, nombre del host, usuarios conectados, espacio libre del disco principal, RAM disponible (columna *available* de `free`) y número de contenedores Docker activos.

```bash
chmod +x /proyecto/scripts/reporte_sistema.sh
ls -l /proyecto/scripts/reporte_sistema.sh
/proyecto/scripts/reporte_sistema.sh
```

#### 2.2 Automatización con cron

El log se guarda en `/var/log/proyecto/reporte_sistema.log`. La tarea se programa en el cron del usuario **`adminsys`**, que pertenece al grupo `docker`; si corriera con un usuario sin acceso a Docker, el conteo de contenedores fallaría.

```bash
sudo apt install -y cron
sudo systemctl enable --now cron

sudo mkdir -p /var/log/proyecto
sudo chown adminsys:adminsys /var/log/proyecto

# Como adminsys:
crontab -e
```

Línea a agregar en el crontab (cada 30 minutos):

```
*/30 * * * * /proyecto/scripts/reporte_sistema.sh >> /var/log/proyecto/reporte_sistema.log 2>&1
```

**Verificación de que el registro se actualiza:**

```bash
crontab -l
systemctl status cron --no-pager
tail -f /var/log/proyecto/reporte_sistema.log
```

Para la evidencia inmediata se probó primero con `* * * * *` (cada minuto), se capturó el log con varias entradas y luego se restauró `*/30 * * * *`. El cron se dejó activo desde el inicio para acumular entradas automáticas separadas por unos 30 minutos.

---

### Sección 5. Servidor web containerizado

#### 5.1 Contenedor Nginx básico

Archivo `/proyecto/web/index.html` (personalizado):

```html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <title>servidor-grupo6 | ISL135</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f4f4f4; text-align: center; margin-top: 60px; }
    h1 { color: #7b1a1a; }
  </style>
</head>
<body>
  <h1>Servidor servidor-grupo6</h1>
  <p>Introducción al Software Libre - Ciclo II 2026</p>
  <p>Universidad de El Salvador - FMOcc</p>
  <p>Integrantes: Nombre 1, Nombre 2, Nombre 3, Nombre 4</p>
  <p>Servido por Nginx en Docker</p>
</body>
</html>
```

El archivo debe quedar con permiso de lectura para todos (`chmod 644`). Contenedor Nginx en segundo plano, puerto 8080→80 y montaje de `/proyecto/web/`:

```bash
ls -l /proyecto/web/index.html

docker run -d --name nginx-oficial -p 8080:80 \
  -v /proyecto/web:/usr/share/nginx/html nginx

docker ps
docker port nginx-oficial
```

#### 5.2 Verificación del servicio web

```bash
curl -I http://localhost:8080
curl http://localhost:8080
docker logs nginx-oficial
```

La verificación principal se hace **con un navegador** en `http://localhost:8080`, donde debe verse el contenido de `index.html`. Los logs deben mostrar la petición `GET / HTTP/1.1` con código 200 y ningún error (la captura de logs se toma después de visitar la página).

---

### Sección 6. Docker avanzado

#### 6.1 Dockerfile personalizado

Archivo `/proyecto/Dockerfile`:

```dockerfile
FROM nginx:latest
COPY web/ /usr/share/nginx/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

Cumple las cuatro condiciones de la guía: imagen base `nginx:latest`, copia del contenido de `web/` al directorio de Nginx, exposición del puerto 80 y comando de inicio de Nginx. Archivo opcional `/proyecto/.dockerignore` para no copiar archivos innecesarios al contexto:

```
.git
capturas
datos
scripts
```

Construcción de la imagen (el contexto es `/proyecto`):

```bash
cd /proyecto
cat Dockerfile
docker build -t servidor-grupo6 .
docker images | grep -E "nginx|servidor"
```

#### 6.2 Contenedor con la imagen personalizada

```bash
docker run -d --name nginx-personalizado -p 8081:80 servidor-grupo6
docker ps
curl -I http://localhost:8081
docker logs nginx-personalizado
```

**Comparación con el contenedor Nginx oficial:**

```bash
docker inspect --format '{{.Config.Image}} | {{.Config.Cmd}} | {{json .Mounts}}' nginx-oficial
docker inspect --format '{{.Config.Image}} | {{.Config.Cmd}} | {{json .Mounts}}' nginx-personalizado
docker history servidor-grupo6
```

| Criterio | Nginx oficial (8080) | Imagen personalizada (8081) |
|---|---|---|
| Origen del contenido | Directorio del host montado en `/usr/share/nginx/html/` | Copiado dentro de la imagen con `COPY` |
| Cambios en `index.html` | Se ven al instante, sin reiniciar | Requieren `docker build` y recrear el contenedor |
| Portabilidad | Depende de que exista `/proyecto/web` en el host | Autocontenida: funciona en cualquier host con Docker |
| Imagen | `nginx` (oficial) | `servidor-grupo6` (basada en `nginx:latest`) |
| Puerto del host | 8080 | 8081 |
| Comando de inicio | El de la imagen oficial | `nginx -g daemon off;` definido en el Dockerfile |

**Prueba de comparación en vivo:** se editó `index.html` (línea extra «Versión 2»). `curl http://localhost:8080` mostró el cambio al instante; `curl http://localhost:8081` no lo mostró porque el contenido quedó dentro de la imagen. Luego se reconstruyó con `docker build -t servidor-grupo6 .`, se recreó el contenedor del 8081 (`docker rm -f nginx-personalizado` y volver a ejecutar) y ambos coincidieron.

---

### Sección 7. Redes y volúmenes Docker

#### 7.1 Red personalizada

```bash
docker network create red-proyecto
docker run -d --name nginx-red --network red-proyecto -p 8082:80 nginx

docker network ls
docker network inspect red-proyecto
docker inspect -f '{{json .NetworkSettings.Networks}}' nginx-red
curl -I http://localhost:8082
```

En la salida de `docker network inspect red-proyecto`, la sección `Containers` lista `nginx-red` con su IP. Este contenedor muestra la página por defecto de Nginx («Welcome to nginx!»), que es lo esperado porque la guía no pide montar contenido.

#### 7.2 Volúmenes persistentes

```bash
docker volume create volumen-web
docker run -d --name nginx-volumen -p 8083:80 \
  -v volumen-web:/usr/share/nginx/html nginx

docker volume ls
docker volume inspect volumen-web
docker inspect -f '{{json .Mounts}}' nginx-volumen
docker exec nginx-volumen ls /usr/share/nginx/html
curl -I http://localhost:8083
```

**Prueba de persistencia** (demuestra que el volumen sobrevive al contenedor):

```bash
docker exec nginx-volumen sh -c 'echo "<h1>Persistencia OK - servidor-grupo6</h1>" > /usr/share/nginx/html/index.html'
curl http://localhost:8083

docker rm -f nginx-volumen
docker run -d --name nginx-volumen -p 8083:80 \
  -v volumen-web:/usr/share/nginx/html nginx
curl http://localhost:8083
```

El segundo `curl` sigue mostrando «Persistencia OK» aunque el contenedor se eliminó y se creó de nuevo.

---

### Sección 8. Pruebas y verificación final

#### 8.1 Pruebas de conectividad

```bash
docker run -it --rm --network red-proyecto --name alpine-test alpine ping -c 4 nginx-red
```

El ping por **nombre** funciona porque las redes definidas por el usuario incluyen DNS interno (la red `bridge` por defecto no resuelve nombres). Resultado esperado: `4 packets transmitted, 4 received, 0% packet loss`.

#### 8.2 Verificación integral

Antes de verificar se elimina el contenedor de prueba de `hello-world` (queda detenido y la guía exige que todos los contenedores estén en ejecución):

```bash
docker rm hello-test
```

Script `/proyecto/scripts/verificacion_final.sh`:

```bash
#!/bin/bash
# verificacion_final.sh - Verificación integral del proyecto
echo "== 1. Servicios web =="
for p in 8080 8081 8082 8083; do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$p)
  echo "Puerto $p -> HTTP $code"
done

echo; echo "== 2. Contenedores en ejecución =="
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}'

echo; echo "== 3. Contenedores detenidos (debe estar vacío) =="
docker ps -a --filter "status=exited" --format '{{.Names}}'

echo; echo "== 4. Cron =="
crontab -l | grep reporte_sistema
echo "Últimas ejecuciones:"
grep "Fecha y hora" /var/log/proyecto/reporte_sistema.log | tail -5

echo; echo "== 5. Git =="
cd /proyecto && git fetch -q && git status -sb
git shortlog -sn
git log --oneline | head -10
```

```bash
chmod +x /proyecto/scripts/verificacion_final.sh
/proyecto/scripts/verificacion_final.sh
```

**Qué debe verse para cumplir el punto 8.2:**

- Los 4 puertos (8080 a 8083) responden con HTTP 200.
- `docker ps` lista los 4 contenedores Nginx con su puerto; ningún contenedor en `Exited`.
- El log del cron tiene entradas separadas por unos 30 minutos, hechas **sin intervención manual**.
- `git status` indica que la rama está al día con `origin/main` y el árbol está limpio; `git shortlog -sn` muestra los **4 autores**.

**Publicación final de los archivos del proyecto:**

```bash
cd /proyecto
git add -A
git commit -m "[S8] Agrega Dockerfile, scripts y configuracion final"
git push
```

---

## 6. Evidencias (capturas)

Todas las capturas se guardan en `capturas/` con el formato `sX_Y_descripcion.png`, mostrando el prompt (`usuario@servidor-grupo6`), el comando y su salida completa.

| Sección | Capturas |
|---|---|
| 1.1 | `s1_1_hostname`, `s1_1_usuarios`, `s1_1_grupos`, `s1_1_campos` |
| 1.2 | `s1_2_estructura` (se ve la `s` del setgid), `s1_2_herencia` |
| 2.1 | `s2_1_script`, `s2_1_ejecucion` |
| 2.2 | `s2_2_cron` (`crontab -l` y estado de cron), `s2_2_log` (entradas en horas distintas) |
| 3 | `s3_git_init_commit`, `s3_github_repo`, `s3_push_remoto`, `s3_readme`, `s3_colaboradores` |
| 4.1 | `s4_1_version`, `s4_1_servicio`, `s4_1_grupo_docker` |
| 4.2 | `s4_2_hello_world`, `s4_2_ps_a` |
| 5 | `s5_1_index`, `s5_1_run`, `s5_2_navegador`, `s5_2_logs` |
| 6 | `s6_1_dockerfile`, `s6_1_build`, `s6_2_run`, `s6_2_navegador`, `s6_2_comparacion` |
| 7 | `s7_1_red`, `s7_1_inspect`, `s7_2_volumen`, `s7_2_mounts`, `s7_2_persistencia` |
| 8 | `s8_1_ping`, `s8_2_puertos`, `s8_2_docker_ps`, `s8_2_cron`, `s8_2_git` |

## 7. Cumplimiento de la guía

| Punto | Requisito | Cómo se cumple |
|---|---|---|
| 1.1 | Hostname, 3 usuarios, 2 grupos, asignaciones | `servidor-grupo6`; `adminsys` (sudo), `tecnico` (soporte), `visitante` (web) |
| 1.2 | Directorios y permisos de grupo con herencia | `/proyecto/{datos,web,scripts,capturas}`; `datos` → `soporte`, `web` → `web`, modo `2775` (setgid) |
| 2.1 | Script con permisos de ejecución y 6 datos | `scripts/reporte_sistema.sh` con `chmod +x` |
| 2.2 | Cron cada 30 min, log verificado | `*/30` en el crontab de `adminsys`; log en `/var/log/proyecto/reporte_sistema.log` |
| 3 | Git local, GitHub y README | `git init` en `/proyecto`, repositorio `proyecto-linux-grupo6`, README.md |
| 4.1 | Docker instalado, servicio, grupo docker | Repositorio oficial, `systemctl enable --now docker`, `adminsys` y `tecnico` en `docker` |
| 4.2 | `hello-world` y listado | `docker run hello-world` y `docker ps -a` |
| 5.1 | Nginx detached, 8080:80, montaje | Contenedor `nginx-oficial` |
| 5.2 | Navegador y logs | `http://localhost:8080` y `docker logs` sin errores |
| 6.1 | Dockerfile (4 instrucciones) y build | Imagen `servidor-grupo6` |
| 6.2 | Contenedor 8081 y comparación | `nginx-personalizado` y tabla comparativa |
| 7.1 | Red `red-proyecto`, puerto 8082 | `nginx-red` conectado a la red |
| 7.2 | Volumen `volumen-web`, puerto 8083 | `nginx-volumen` con prueba de persistencia |
| 8.1 | Alpine y ping | `alpine-test` → `nginx-red` |
| 8.2 | Verificación integral | `scripts/verificacion_final.sh` |

## 8. Flujo de trabajo en Git (equipo de 4)

Como el servidor es compartido, cada integrante hace sus commits desde su propio clon con su identidad y el servidor solo descarga los cambios.

```bash
# Cada integrante, una sola vez, en su equipo
git clone git@github.com:Agusserr/proyecto-linux-grupo6.git
cd proyecto-linux-grupo6
git config user.name "Nombre Apellido"
git config user.email "correo-asociado-a-su-GitHub"
git config core.autocrlf input

# Ciclo de trabajo
git add <archivos>
git commit -m "[S5] Agrega index.html personalizado"
git pull --rebase origin main
git push origin main

# En el servidor (como adminsys), para publicar lo nuevo
cd /proyecto && git pull
```

- Mensajes de commit con prefijo de sección: `[S1]`, `[S2]`, `[S5]`, etc.
- Mínimo de 3 a 5 commits por integrante, con archivos reales (scripts, Dockerfile, `index.html`, secciones del README).
- Se usa el mismo correo que la cuenta de GitHub para que los commits se atribuyan a cada integrante.
- Siempre `git pull --rebase` antes de `git push`; nunca `git push --force` sobre `main`.

## 9. Solución de problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `permission denied` con `docker ps` | El usuario no está en el grupo `docker` o la sesión es anterior al cambio | `getent group docker`; cerrar sesión y volver a entrar, o `newgrp docker` |
| `port is already allocated` | El puerto ya lo usa otro contenedor o servicio | `sudo ss -tulpn \| grep 8080`; `docker rm -f <nombre>` |
| `git push` falla por autenticación | GitHub no acepta contraseña de cuenta | Usar llave SSH (deploy key con escritura) o token personal |
| `fatal: detected dubious ownership` | El repositorio pertenece a otro usuario | `git config --global --add safe.directory /proyecto` |
| Directorios vacíos no aparecen en GitHub | Git no versiona carpetas vacías | Agregar `.gitkeep` |
| El cron no escribe el log | Permisos de `/var/log/proyecto`, ruta relativa o usuario sin Docker | Dueño `adminsys`, ruta absoluta y crontab de `adminsys`; revisar con `journalctl -u cron` |
| Nginx responde «403 Forbidden» | Falta `index.html` o no tiene permiso de lectura | `ls -l /proyecto/web`; `chmod 644 index.html` |
| `COPY failed` en `docker build` | Se construye fuera de `/proyecto` | Ejecutar `docker build -t servidor-grupo6 .` desde `/proyecto` |
| El ping por nombre falla | El contenedor no está en `red-proyecto` | Usar `--network red-proyecto` en ambos |

## 10. Entregables

1. **Informe PDF:** portada, desarrollo de cada apartado con captura de cada comando, evidencias de todos los servicios funcionando y explicación de cada fase.
2. **Repositorio GitHub** (este repositorio): estructura completa, scripts de automatización, Dockerfile y configuraciones, README.md con documentación completa e historial de commits de todos los integrantes.
3. **Presentación (20 minutos máximo):** demostración en vivo del servidor funcionando, explicación de la arquitectura, participación equitativa de todos los integrantes y respuestas a preguntas del docente y compañeros.

## 11. Referencias

- Guía del proyecto final ISL135, Universidad de El Salvador, Ciclo II – 2026.
- Documentación oficial de Docker: <https://docs.docker.com/engine/install/ubuntu/>
- Documentación de Git: <https://git-scm.com/doc>
