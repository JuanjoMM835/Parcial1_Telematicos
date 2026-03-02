Parcial 1 – DNS Maestro/Esclavo con BIND9 + Apache con compresión
Realizado por : Juan Jose Moncayo Martinez 
Entorno: Windows (host) + VirtualBox + Vagrant  
VMs: Ubuntu (Vagrant box `ubuntu/jammy64`)  
Objetivo:
1) Implementar DNS autoritativo maestro/esclavo con BIND9 (zonas directa e inversa + NOTIFY + AXFR seguro + medidas de seguridad).  
2) Montar servidor Apache con compresión gzip usando mod_deflate, configurar exclusiones y verificar desde “clientes” o el esclavo 

 1. Topología del laboratorio

Se crean 2 máquinas virtuales usando Vagrant:

- VM1: maestro.empresa.local  
  - IP: 192.168.56.10 
  -Rol: DNS Maestro (BIND9) + Servidor web (Apache)
- VM2:: esclavo.empresa.local 
  -IP: 192.168.56.11  
  -Rol: DNS Esclavo (BIND9) y se usa como “cliente” para pruebas con dig y curl

Red privada de VirtualBox/Vagrant: 192.168.56.0/24

2. Creación de las máquinas con Vagrant

En Windows se creó una carpeta de trabajo y un `Vagrantfile` con 2 VMs, cada una con hostname y una IP fija en red privada.

2.1 Levantar máquinas
Desde la carpeta del proyecto:

- vagrant up

2.2 Acceder por SSH
- vagrant ssh vm1-maestro
- vagrant ssh vm2-esclavo

 3. Configuración DNS con BIND9 (Maestro / Esclavo)

3.1 Instalación de paquetes
En ambas VMs:

- sudo apt update
- sudo apt install -y bind9 bind9utils dnsutils

Se verificó el servicio:

- sudo systemctl status bind9 

 4. Configuración de BIND9 en VM1 (Maestro)

 4.1 Seguridad: evitar open resolver
En el maestro se configuró BIND como autoritativo: no debe resolver dominios externos (no recursión pública).

Archivo: /etc/bind/named.conf.options

Conceptos aplicados:
- Recursión desactivado: recursion no
- Bloqueo de recursión: allow-recursion { none; }`
- Permitir consultas solo desde red local: allow-query { localhost; 192.168.56.0/24; };

Se validó sintaxis y reinició:

- sudo named-checkconf
- sudo systemctl restart bind9

4.2 Zonas configuradas en el maestro
Archivo: /etc/bind/named.conf.local

Se definieron:
1) Zona directa principal: empresa.local
2) Zona inversa: 56.168.192.in-addr.arpa
3) Zona adicional (para Apache): juanjo.com

 Transferencia segura y NOTIFY
Para cada zona en el maestro se aplicó:
- allow-transfer 192.168.56.11 solo el esclavo puede hacer AXFR
- also-notify 192.168.56.11 y notify yes;  notificar cambios al esclavo automáticamente

4.3 Zona directa empresa.local
Archivo: /etc/bind/db.empresa.local

Registros creados:
- NS: maestro y esclavo
- A:
  - maestro → `192.168.56.10`
  - esclavo → `192.168.56.11`
  - www→ `192.168.56.10
- CNAME:
  - dns→ maestro

Validación:
- sudo named-checkzone empresa.local /etc/bind/db.empresa.local
4.4 Zona inversa 56.168.192.in-addr.arpa
Archivo: /etc/bind/db.192.168.56

Registros PTR:
- 10→ maestro.empresa.local
- 11 → esclavo.empresa.local

Validación:
- sudo named-checkzone 56.168.192.in-addr.arpa /etc/bind/db.192.168.56

4.5 Recarga final del maestro
- sudo rndc reload
- sudo systemctl status bind9 



5. Configuración de BIND9 en VM2 (Esclavo)

5.1 Seguridad equivalente
En VM2 también se dejó como autoritativo (sin recursión pública) en:

- /etc/bind/named.conf.options

Con:
- recursion no;
- allow-recursion { none; };
- allow-query { localhost; 192.168.56.0/24; };

5.2 Zonas como esclavo
Archivo: /etc/bind/named.conf.local

Se declararon como `type slave` y apuntando al maestro:

- masters { 192.168.56.10; }
- Archivos guardados en `/var/lib/bind/

Reinicio:
- sudo systemctl restart bind9

Verificación de que se generaron archivos transferidos:
- sudo ls -l /var/lib/bind/



6. Verificación DNS

6.1 Resolución desde el esclavo
En VM2 se probó que responde:

- dig @192.168.56.11 maestro.empresa.local A
- dig @192.168.56.11 dns.empresa.local CNAME
- dig @192.168.56.11 maestro.empresa.local AAAA

6.2 Resolución inversa (PTR)
- dig @192.168.56.11 -x 192.168.56.10
- dig @192.168.56.11 -x 192.168.56.11

6.3 Evitar open resolver 
Se comprobó que no resuelve dominios externos:

- dig @192.168.56.10 google.com A
- dig @192.168.56.11 google.com A

Resultado esperado: no debe actuar como resolver recurso público.

7. Configuración de Apache en VM1 
7.1 Instalación de Apache
En VM1:

- sudo apt update
- sudo apt install -y apache2
- sudo systemctl enable --now apache2

Prueba local:
- curl -I http://127.0.0.1

7.2 Contenido de prueba
Se creó un directorio:

- /var/www/parcial

Y archivos de prueba:
- index.html
- style.css
- app.js

El objetivo es disponer de HTML/CSS/JS para comprobar compresión gzip.

7.3 VirtualHost para parcial.juanjo.com
Se creó un sitio en:

- /etc/apache2/sites-available/parcial.conf

Configuración principal:
- ServerName parcial.juanjo.com
- DocumentRoot /var/www/parcial

Se habilitó y recargó Apache:

- sudo a2ensite parcial.con
- sudo a2dissite 000-default.conf 
- sudo apache2ctl configtest
- sudo systemctl reload apache2



8. Compresión gzip con mod_deflate

8.1 Activación de módulos
En VM1:

- sudo a2enmod deflate
- sudo a2enmod headers
- sudo systemctl restart apache2

8.2 Reglas de compresión y exclusiones
Se creó un archivo de configuración adicional:

- /etc/apache2/conf-available/parcial-deflate.conf

Reglas aplicadas:
- Comprimir: `text/html`, `text/css`, `application/javascript`, `application/json`, `application/xml`, `image/svg+xml`, etc.
- Agregar cabecera: `Vary: Accept-Encoding`
- Excluir (no comprimir): imágenes y multimedia ya comprimidas (`.png`, `.jpg`, `.gif`, `.mp4`, `.mp3`, `.pdf`, `.zip`, etc.) usando `SetEnvIfNoCase ... no-gzip`.

Habilitación:
- sudo a2enconf parcial-deflate.conf
- sudo apache2ctl configtest
- sudo systemctl reload apache2

9. DNS para parcial.juanjo.com

Para que el servidor responda correctamente al nombre (sin usar /etc/hosts), se creó una zona DNS:

- juanjo.com

En el maestro (VM1):
- etc/bind/named.conf.local se agregó la zona con allow-transfer al esclavo y notify al esclavo.
- Se creó el archivo: /etc/bind/db.juanjo.com con:

Registro:
- parcial` → 192.168.56.10 

Se validó y recargó BIND:
- sudo named-checkzone su-nombre.com /etc/bind/db.su-nombre.com
- sudo rndc reload

En el esclavo (VM2):
- Se agregó la zona juanjo.com como type slave para que la transfiera desde el maestro.
- sudo systemctl restart bind9`
- Se verificó que exista el archivo en /var/lib/bind/


 10. Pruebas de acceso web y verificación de compresión revisión de páginas

10.1 Verificar DNS desde VM2 usando el esclavo
En VM2:

- dig @192.168.56.11 parcial.su-nombre.com A
Debe devolver:
- 192.168.56.10

10.2 Verificar acceso HTTP al sitio
En VM2:

- curl -I http://parcial.su-nombre.com/

Debe responder con estado `200 OK` (o similar) desde Apache en VM1.

10.3 Verificar compresión gzip con curl
Sin pedir gzip:
- curl -I http://parcial.su-nombre.com/
Pidiendo gzip:
- curl -I -H "Accept-Encoding: gzip" http://parcial.su-nombre.com/

Resultado esperado cuando gzip se aplica:
- Aparece: Content-Encoding: gzip
- Aparece: Vary: Accept-Encoding

10.4 Comparación comprimido vs no comprimido
En VM2 se midió el tamaño descargado:

- curl -s -o /dev/null -w "size_download=%{size_download}\n" http://parcial.su-nombre.com/
- curl -s -H "Accept-Encoding: gzip" -o /dev/null -w "size_download=%{size_download}\n
http://parcial.juanjo.com/

