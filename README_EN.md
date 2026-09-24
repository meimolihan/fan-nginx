# fan-nginx

#### Introduce

fan-nginx is an open-source web-based management platform for Nginx. It is built with the Solon framework and an embedded SQLite database, so no standalone database is required — deploy and use it right away.

Through a clean web interface, you can handle Nginx configuration and administration tasks, covering about 90% of everyday Nginx configuration scenarios. For settings not covered by the platform, custom parameter templates let you generate exactly the configuration you need, keeping your nginx.conf fully under your control.

- Github: [https://github.com/meimolihan/fan-nginx](https://github.com/meimolihan/fan-nginx)
- Docker Hub: [https://hub.docker.com/r/mobufan/fan-nginx](https://hub.docker.com/r/mobufan/fan-nginx)

#### Features

- Visual configuration: add, edit, delete parameters from the web page and generate nginx.conf with one click
- Protocol forwarding: HTTP and TCP/Stream forwarding rules
- Reverse proxy: configure server blocks visually, with SSL, HTTP/2 and HTTP-to-HTTPS redirect support
- Load balancing: configure upstream clusters visually and reference them from reverse proxy rules
- Certificate management: auto-issue and auto-renew SSL certificates with acme.sh, or upload pem/key files via the web page
- Static sites: upload HTML archives to a target path from the browser, no shell needed
- Multi-server management: manage multiple Nginx servers from a single machine, with one-click config synchronization
- Backup & rollback: keep backup history of nginx.conf and roll back with one click
- IP access control: blacklist/whitelist for both HTTP and Stream
- Password files: manage HTTP Basic Auth password files
- API: built-in smart-doc API documentation for integration and automation

#### Technical note

- Backend uses Java 8 and the Solon framework; default database is SQLite, with MySQL and PostgreSQL also supported
- Certificates are issued and renewed automatically via Let's Encrypt + acme.sh, supported on Linux only
- Expiring certificates are checked every day at 2 AM; only certificates that expire within 60 days are renewed
- The Nginx stream module works out of the box on modern Nginx builds; older self-compiled Nginx needs to be built with the `--with-stream` flag
- The stream module config is only introduced when TCP forwarding is enabled, keeping nginx.conf as lean as possible

#### jar installation instructions 
Take the Ubuntu operating system, for example.

 **Note: This project needs to run the system command under the root user, which is very easy to be exploited by hackers. Please be sure to change the password to complex password**

1.Install the Java runtime environment and Nginx

Ubuntu:

```
apt install openjdk-11-jdk
apt install nginx
```

Centos:

```
yum install java-11-openjdk
yum install nginx
```

Windows:

```
Download the JDK installation package https://www.oracle.com/java/technologies/downloads/
Download the nginx http://nginx.org/en/download.html
Configure the JAVA runtime environment 
JAVA_HOME : JDK installation directory
Path : JDK installation directory\bin
reboot
```

2.Download the latest release of the distribution jar

```
Linux: mkdir /home/fan-nginx/   
       wget -O /home/fan-nginx/fan-nginx.jar https://github.com/meimolihan/fan-nginx/releases/download/v4.4.2/fan-nginx-4.4.2.jar

Windows: Download directly from your browser https://github.com/meimolihan/fan-nginx/releases/download/v4.4.2/fan-nginx-4.4.2.jar into D:/home/fan-nginx/
```

With a new version, you just need to change the version in the path

3.Start program

```
Linux: nohup java -jar -Dfile.encoding=UTF-8 /home/fan-nginx/fan-nginx.jar --server.port=8080 --project.home=/home/fan-nginx/ > /dev/null &

Windows: java -jar -Dfile.encoding=UTF-8 D:/home/fan-nginx/fan-nginx.jar --server.port=8080 --project.home=D:/home/fan-nginx/
```

Parameter description (both non-required)

--server.port Occupied port, default starts at port 8080

--project.home Project profile directory for database files, certificate files, logs, etc. Default is /home/fan-nginx/

--spring.database.type=mysql Use other databases, not filled with native sqlite, options include mysql postgresql

--spring.datasource.url=jdbc:mysql://ip:port/fan-nginx Databases url

--spring.datasource.username=root  Databases user

--spring.datasource.password=pass  Databases password

--init.admin=admin  Initial user name

--init.pass=admin  Initial user password

--init.api=true  Initial user enables the api permission

Note that the Linux command ends with an & to indicate that the project is running in the background

#### docker installation instructions 

Docker image supports x86_64/arm64/arm v7 platforms. Note that an & sign is added at the end of the command, indicating that the docker image of this project has been produced by the background operation of the project, including nginx and fan-nginx, for integrated management and operation of Nginx.

1.Install the Docker environment

ubuntu:

```
apt install docker.io
```

centos:

```
yum install docker
```

2.Download images:

```
docker pull mobufan/fan-nginx:latest
```

3.start container

```
docker run -itd \
  -v /home/fan-nginx:/home/fan-nginx \
  -e BOOT_OPTIONS="--server.port=8080" \
  --net=host \
  --restart=always \
  mobufan/fan-nginx:latest
```

notice: 

1. When you start the container, use the --net=host parameter to map the native port directly, because internal Nginx may use any port, so you must map all the native ports. 

2. Container need to map path/home/fan-nginx:/home/fan-nginx, this path for a project all data files, including database, nginx configuration files, log, certificate, etc., and updates the mirror, this directory to ensure that project data is not lost. Please note that backup.

3. -e BOOT_OPTIONS Parameter to populate the Java startup parameter, which can be used to modify the port number

--server.port Occupied port, do not fill the default port 8080 startup

4. Logs are stored by default /home/fan-nginx/log/fan-nginx.log

moreover: The following configuration file is used when using docker-compose

```
version: "3.2"
services:
  fan-nginx-server:
    image: mobufan/fan-nginx:latest
    volumes:
      - type: bind
        source: "/home/fan-nginx"
        target: "/home/fan-nginx"
    environment:
      BOOT_OPTIONS: "--server.port=8080"
    network_mode: "host"
    restart: always
```


#### Script installation (systemd one-click install / upgrade)

For Linux servers we recommend the one-click install script, which automatically deploys the jar, checks/installs nginx, registers the systemd service, enables boot autostart and opens the firewall. It is idempotent: re-running is an upgrade (the data directory is always kept).

```
# Interactive install (asks for port and data dir)
bash scripts/install.sh

# Silent install with args: port + data dir, and initialize an admin account
bash scripts/install.sh -p 8080 -d /var/lib/fan-nginx -u admin -P 123456

# Install from a locally built jar (no source code / maven needed)
bash scripts/install.sh -p 8080 -d /var/lib/fan-nginx -j /tmp/fan-nginx-4.4.2.jar

# Online: download the prebuilt jar from GitHub Releases (default)
bash scripts/install.sh -p 8080 -b

# Pick a GitHub mirror for restricted networks
FAN_NGINX_REPO=https://ghfast.top/https://github.com/meimolihan/fan-nginx.git bash scripts/install.sh -y
```

Remote install (there is no need to clone the source to the target server; recommended):

```
# Run install.sh remotely on the target server; it auto-downloads the prebuilt jar from GitHub Releases and installs it as a systemd service
bash -c "$(curl -sSL https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/install.sh)" -p 8080 -d /var/lib/fan-nginx -u admin -P YOUR_STRONG_PASSWORD

# Interactive remote install (asks for port and data dir)
bash -c "$(curl -sSL https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/install.sh)"

# Remote install through a GitHub mirror for restricted networks
FAN_NGINX_REPO=https://ghfast.top/https://github.com/meimolihan/fan-nginx.git bash -c "$(curl -sSL https://raw.githubusercontent.com/meimolihan/fan-nginx/main/scripts/install.sh)" -y
```

Remote install performs the same steps: jar deployment, nginx check/install, systemd service registration, boot autostart, firewall opening and CLI installation. Once finished, run `fan-nginx status` on the target machine to verify.

After installation:

- Data directory: `/var/lib/fan-nginx` (sqlite.db, nginx configs, certificates, logs, ...)
- Install record: `/etc/fan-nginx.conf`
- systemd unit: `fan-nginx.service`
- Built-in CLI: `/usr/local/bin/fan-nginx`

Uninstall:

```
bash scripts/uninstall.sh -y --purge      # uninstall without prompting and purge data dir
bash scripts/uninstall.sh                 # interactive uninstall (keeps data by default)
```

#### systemctl service management

```
systemctl start fan-nginx          # start
systemctl stop fan-nginx           # stop
systemctl restart fan-nginx        # restart
systemctl status fan-nginx         # status
systemctl enable fan-nginx         # enable autostart on boot
journalctl -u fan-nginx -f         # follow logs
```

#### Built-in CLI commands

The install script also installs a `fan-nginx` command line tool (same command style as the fan-webssh family of panels), so you no longer need to remember the verbose java commands:

```
fan-nginx status                  # runtime/systemd/PID/port/URL/uptime/memory/paths
fan-nginx credentials             # reset and print all admin accounts and passwords (disables 2FA)
fan-nginx start | stop | restart  # start/stop/restart the systemd service
fan-nginx uninstall [-y] [--purge|--keep-data]  # uninstall
fan-nginx version                 # show version
fan-nginx help                    # show help
```

#### Backup and restore

Command-line backup/restore scripts matching the panel's "Backup file management" are provided (deployed to `/var/lib/fan-nginx/scripts` on install):

```
# Backup the data directory (keeps the last 6 archives by default, FanNginx-TIMESTAMP.tar.gz)
bash /var/lib/fan-nginx/scripts/fan-nginx_backup.sh

# Restore the latest backup (stops the service)
bash /var/lib/fan-nginx/scripts/fan-nginx_recover.sh
```

#### Compile 

Compile the package with Maven

```
mvn clean package
```

Compile the image with Docker

```
docker build -t mobufan/fan-nginx:latest .
```


#### instructions

open http://xxx.xxx.xxx.xxx:8080 Enter the main page

![输入图片说明](README/login.jpeg "login.jpg")

The login page, opened for the first time, asks to initialize the administrator account

![输入图片说明](README/admin.jpeg "admin.jpg")

After entering the system, you can add and modify the administrator account in the administrator management

![输入图片说明](README/http.jpeg "http.jpg")

In the HTTP parameters can be configured in the configuration of nginx HTTP project forward HTTP, the default will give several commonly used configuration, other configuration are free to add and delete. You can check the open log to track and generate log.

![输入图片说明](README/tcp.jpeg "tcp.jpg")

Nginx's Stream project parameters can be configured in the TCP parameter configuration, but in most cases they are not.

![输入图片说明](README/server.jpeg "server.jpg")

In the reverse proxy, the reverse proxy of Nginx, namely the Server item function, can be configured to enable SSL function, can directly upload PEM file and key file from the web page, or use the certificate applied in the system, can directly enable HTTP switch HTTPS function, or can open http2 protocol

![输入图片说明](README/upstream.jpeg "upstream.jpg")

In load balancing, the upstream function of Nginx can be configured. In reverse agent management, the configured load balancing agent target can be selected

![输入图片说明](README/html.jpeg "html.jpg")

In the HTML static file upload can be directly uploaded HTML compression package to the specified path, after uploading can be directly used in the reverse proxy, save the steps of uploading HTML files in Linux

![输入图片说明](README/cert.jpeg "cert.jpg")

In the certificate management, you can add the certificate, issue and renew it. After the periodic renewal is started, the system will automatically renew the certificate which will expire soon. Note: the certificate is issued using the DNS mode of Acme. sh, and it needs to be used together with aliKey and aliSecret of Aliyun

![输入图片说明](README/bak.jpeg "bak.jpg")

Backup file management. Here you can see the backup history version of Nginx.cnF. If an error occurs in Nginx, you can choose to roll back to a certain history version

![输入图片说明](README/conf.jpeg "conf.jpg")

Finally, the conF file can be generated, which can be further modified manually. After the modification is confirmed to be correct, the native conF file can be overwritten, and the effectiveness and restart can be carried out. You can choose to generate a single Nginx.conf file or separate each configuration file under conF.d by domain name
 
![输入图片说明](README/remote.jpeg "remote.jpg")

Remote server management. If you have multiple Nginx servers, you can deploy fan-nginx, log in to one of them, add the IP and username and password of other servers to the remote management, and then you can manage all Nginx servers on one machine.

Provides one-click synchronization to synchronize data configuration and certificate files from one server to another

#### Interface development 

This system provides the HTTP interface to invoke. Open the page http://xxx.xxx.xxx.xxx:8080/doc.html to view the smart-doc interface.  

The interface invocation requires adding a token to the HTTP request header. To obtain the token, you need to enable the interface invocation permission of the user in the administrator management system, and then invoke the interface to obtain the token using the user name and password.  

![输入图片说明](README/smart-doc.png "smart-doc.png")

#### Forgot Password

If you forget your login password or don't save the two-step verification QR code, you can reset your password and turn off two-step verification by following the tutorial below.

1.Script installation — use the built-in CLI (recommended)

```
fan-nginx credentials
```

It is equivalent to the command below. After it runs successfully, all usernames and passwords are reset and printed, and two-step verification is disabled.

2.jar installation, execute the command


```
java -jar /home/fan-nginx/fan-nginx.jar --project.home=/home/fan-nginx/ --project.findPass=true
```

--project.home Project profile directory or docker mapping directory

--project.findPass Whether to print the user name and password

After the operation is successful, all user names and passwords can be reset printed and two steps verify will disabled.

3.docker installation, first execute the command to enter the docker container, where {ID} is the id of the container

```
docker exec -it {ID} /bin/sh
```

Then execute the command

```
java -jar /home/fan-nginx.jar --project.findPass=true
```

After the operation is successful, all user names and passwords can be reset printed and two steps verify will disabled.