# SMTPUser.sh

![banner](./banner.png)

**SMTPUser** es un script _bash_ que **enumera usuarios válidos** en un servidor SMTP utilizando los comandos `VRFY` o `RCPT TO`.  
Incluye soporte para **concurrencia**, **timeouts configurables** y **salida en color** al estilo *ffuf/wfuzz*. Su banner ASCII -glitch le da un toque retro, mientras que la ayuda en colores facilita la lectura rápida de las opciones.

> **Autor** · [bytuch0](https://github.com/tuch0)  
> **Licencia** · MIT

---

## ⚙️  Características

| Función                     | Detalle                                                                           |
|-----------------------------|-----------------------------------------------------------------------------------|
| **Métodos de enumeración**  | `VRFY` (por defecto) o `RCPT TO` cuando `VRFY` está deshabilitado                  |
| **Paralelización**          | Lanzamiento multihilo (nº de hilos configurable)                                  |
| **Timeouts**                | Tiempo de espera por petición ajustable                                           |
| **Wordlists**               | Acepta cualquier lista de nombres de usuario (UTF-8)                              |
| **Verbose**                 | Modo detallado para ver cada intento                                              |
| **Banner Glitch**           | Banner ASCII personalizado en colores pastel                                      |
| **Interrupción amable**     | `Ctrl+C` limpia procesos y muestra mensaje en rojo                                 |
| **Salida estilo ffuf**      | Muestra solo los usuarios válidos en verde + respuesta SMTP                       |

---

## 📦  Instalación

> Requisitos: **bash**, **nc (netcat)**, **timeout** (GNU coreutils), **awk**

```bash
git clone https://github.com/tuch0/SMTPUser.git
cd SMTPUser
chmod +x SMTPUser.sh
````

---

## 🚀  Uso rápido

```bash
./SMTPUser.sh -d <IP|HOST> -w <wordlist.txt> [opciones]
```

### Ejemplos

```bash
# Enumerar con VRFY, 8 hilos, timeout 10 s:
./SMTPUser.sh -d mail.ejemplo.com -w users.txt -t 8 -T 10 -m VRFY -v

# Enumerar con RCPT TO porque VRFY está bloqueado:
./SMTPUser.sh -d 10.10.10.25 -w footprinting.txt -m RCPT

# Escaneo básico con valores por defecto (VRFY, 5 hilos, 7 s timeout):
./SMTPUser.sh -d smtp.target.htb -w top100.txt
```

---

## 📝  Opciones

| Opción | Valor           | Descripción                                        |
| ------ | --------------- | -------------------------------------------------- |
| `-d`   | **\<TARGET>**   | IP o dominio del servidor SMTP (**obligatorio**).  |
| `-w`   | **\<WORDLIST>** | Ruta a la wordlist de usuarios (**obligatorio**).  |
| `-p`   | *25*            | Puerto SMTP (por defecto 25).                      |
| `-t`   | *5*             | Número de hilos concurrentes.                      |
| `-T`   | *7* seg         | Timeout por intento (segundos).                    |
| `-m`   | `VRFY` / `RCPT` | Método de enumeración.                             |
| `-v`   | ―               | Modo verbose (muestra cada usuario que se prueba). |
| `-h`   | ―               | Mostrar ayuda y salir.                             |

---

## 🖥️  Ejemplo de salida

██████  ███▄ ▄███▓▄▄▄█████▓ ██▓███   █    ██   ██████ ▓█████  ██▀███  "
▒██    ▒ ▓██▒▀█▀ ██▒▓  ██▒ ▓▒▓██░  ██▒ ██  ▓██▒▒██    ▒ ▓█   ▀ ▓██ ▒ ██▒"
░ ▓██▄   ▓██    ▓██░▒ ▓██░ ▒░▓██░ ██▓▒▓██  ▒██░░ ▓██▄   ▒███   ▓██ ░▄█ ▒"
▒   ██▒▒██    ▒██ ░ ▓██▓ ░ ▒██▄█▓▒ ▒▓▓█  ░██░  ▒   ██▒▒▓█  ▄ ▒██▀▀█▄  "
▒██████▒▒▒██▒   ░██▒  ▒██▒ ░ ▒██▒ ░  ░▒▒█████▓ ▒██████▒▒░▒████▒░██▓ ▒██▒"
▒ ▒▓▒ ▒ ░░ ▒░   ░  ░  ▒ ░░   ▒▓▒░ ░  ░░▒▓▒ ▒ ▒ ▒ ▒▓▒ ▒ ░░░ ▒░ ░░ ▒▓ ░▒▓░"
░ ░▒  ░ ░░  ░      ░    ░    ░▒ ░     ░░▒░ ░ ░ ░ ░▒  ░ ░ ░ ░  ░  ░▒ ░ ▒░"
░  ░  ░  ░      ░     ░      ░░        ░░░ ░ ░ ░  ░  ░     ░     ░░   ░ "
      ░         ░                        ░           ░     ░  ░   ░     "
                     SMTPUser.sh  -  Enumerador de usuarios SMTP
                                                            by tuch0

[*] Objetivo:        10.129.218.190:25
[*] Wordlist:        users.txt
[*] Método:          VRFY
[*] Hilos:           8
[*] Timeout (s):     10

[>] Probando: juan.perez
[>] Probando: maria.gomez
[+] Encontrado: mrb3n [SMTP OK]
    ------------------------
    250 2.1.5 mrb3n
    ------------------------

---

## ❓Preguntas frecuentes

| P                                           | R                                                                                                                                          |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **¿Por qué recibir `252` en vez de `250`?** | Algunos servidores responden `252 2.5.2 Cannot VRFY…` cuando ocultan la verificación; el script lo toma como indicio de usuario existente. |
| **¿El servidor no responde a `VRFY`?**      | Usa `-m RCPT`. El método `MAIL FROM` + `RCPT TO` suele seguir operativo.                                                                   |
| **¿Cómo evitar falsos negativos?**          | Aumenta `-T` (timeout) y baja el nº de hilos `-t` si el servidor va lento.                                                                 |

---

## 🤝 Contribuir

1. Haz un fork del repositorio.
2. Crea tu rama con la mejora: `git checkout -b feature/nueva-funcionalidad`
3. Haz *commit*: `git commit -am 'Añadir nueva funcionalidad'`
4. Envía el *pull request*.

---

## 📜  Licencia

Distribuido bajo la licencia **MIT**. Consulta el archivo `LICENSE` para más información.

---

> *«Hack the Box - Footprinting made fun!»*
