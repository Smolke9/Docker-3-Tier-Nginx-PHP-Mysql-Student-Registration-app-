
# Student-App — Docker 3-Tier Manual (Manual `docker run` only)

**Author:** Suraj  
**Project:** Student Registration (Nginx + PHP-FPM + MySQL)  
**Purpose:** Manual steps (no `docker-compose`) to run a 3-container Docker stack with two Docker networks: `frontend` and `backend`.

---

## Overview

This repository contains a minimal Student Registration web app and a step-by-step guide to run it using Docker `run` commands (no `docker-compose`).  
The stack:

- **nginx** — serves static files + forwards PHP to PHP-FPM (on `frontend` network)  
- **php-fpm** — runs PHP and connects to both `frontend` and `backend` networks; includes `mysqli` extension  
- **mysql:8.0** — database (on `backend` network), initialized using `mysql-init/init.sql`

---

## Host folder layout

You should create the following folder structure on the Ubuntu host (example: `~/student-app`):

```
student-app/
├── www/
│   ├── index.html
│   ├── register.php
│   └── db.php
├── nginx/
│   └── default.conf
└── mysql-init/
    └── init.sql
```

---

## Prerequisites (on Ubuntu)

```bash
# update packages
sudo apt update && sudo apt upgrade -y

# install docker and docker-compose (optional, compose not used here)
sudo apt install -y docker.io docker-compose

# enable & start docker
sudo systemctl enable --now docker

# allow your user to run docker without sudo (logout/login required)
sudo usermod -aG docker $USER
```

---

## Files (copy exact contents)

### `www/index.html`
```html
<!DOCTYPE html>
<html>
<head>
<title>Student Register</title>
</head>
<body>
<h2>Student Registration</h2>
<form action="register.php" method="POST">
    Name: <input type="text" name="fullname" required><br><br>
    Email: <input type="email" name="email" required><br><br>
    Roll No: <input type="text" name="roll" required><br><br>
    <button type="submit">Submit</button>
</form>
</body>
</html>
```

### `www/db.php`
```php
<?php
$mysqli = new mysqli("mysql", "studentuser", "studentpass", "studentdb");

if ($mysqli->connect_error) {
    die("DB Connection failed: " . $mysqli->connect_error);
}
?>
```

### `www/register.php`
```php
<?php
require __DIR__ . "/db.php";

$fullname = $_POST['fullname'] ?? '';
$email = $_POST['email'] ?? '';
$roll = $_POST['roll'] ?? '';

$stmt = $mysqli->prepare("INSERT INTO students(fullname,email,roll) VALUES (?,?,?)");
$stmt->bind_param("sss", $fullname, $email, $roll);

if ($stmt->execute()) {
    echo "Student Registered Successfully!";
} else {
    echo "Error: " . $stmt->error;
}
?>
```

### `nginx/default.conf`
```nginx
server {
    listen 80;
    root /var/www/html;
    index index.html index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php-fpm:9000;
        fastcgi_param SCRIPT_FILENAME /var/www/html$fastcgi_script_name;
    }
}
```

### `mysql-init/init.sql`
```sql
CREATE DATABASE IF NOT EXISTS studentdb;

CREATE USER IF NOT EXISTS 'studentuser'@'%' IDENTIFIED BY 'studentpass';
GRANT ALL PRIVILEGES ON studentdb.* TO 'studentuser'@'%';
FLUSH PRIVILEGES;

USE studentdb;

CREATE TABLE IF NOT EXISTS students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  fullname VARCHAR(255),
  email VARCHAR(255),
  roll VARCHAR(255)
);
```

---

## Step-by-step Docker commands (manual)

> Run each command on the Ubuntu server where files/folders above exist (e.g. `~/student-app`).

### 1) Create Docker networks
```bash
docker network create frontend
docker network create backend
```

### 2) Start MySQL container (on backend)
```bash
docker run -d \
  --name mysql \
  --network backend \
  -e MYSQL_ROOT_PASSWORD=rootpass123 \
  -v ~/student-app/mysql-data:/var/lib/mysql \
  -v ~/student-app/mysql-init:/docker-entrypoint-initdb.d \
  mysql:8.0
```
- `mysql-init` SQL files are executed only on the first initialization of the data directory.

### 3) Start PHP-FPM container with `mysqli` extension
The official `php:8.1-fpm` image does not include `mysqli` by default. Install on container start and run `php-fpm`:

```bash
docker run -d \
  --name php-fpm \
  -v ~/student-app/www:/var/www/html \
  php:8.1-fpm bash -c "docker-php-ext-install mysqli && php-fpm"
```

### 4) Connect PHP container to both networks
```bash
docker network connect backend php-fpm
docker network connect frontend php-fpm
```

### 5) Start Nginx container (frontend network)
```bash
docker run -d \
  --name nginx \
  --network frontend \
  -p 80:80 \
  -v ~/student-app/www:/var/www/html:ro \
  -v ~/student-app/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx
```

---

## Verify & Test

1. Visit `http://<SERVER_IP>/` in your browser.  
2. Fill in the form and submit.  
3. Check MySQL data:

```bash
docker exec -it mysql mysql -u root -p
# password: rootpass123

USE studentdb;
SELECT * FROM students;
```

4. Troubleshoot: list files inside PHP container

```bash
docker exec -it php-fpm ls -l /var/www/html
docker exec -it php-fpm php -m | grep mysqli
```

---

## Common Troubleshooting

- **`require 'db.php'` not found:** verify host folder mounted and container sees files:
  ```bash
  docker exec -it php-fpm ls -l /var/www/html
  ```
  If missing, recreate php-fpm container with correct `-v` flag.

- **`Class "mysqli" not found`:** you must install `mysqli`. Use the php run command above or build a custom image with `docker-php-ext-install mysqli`.

- **MySQL init scripts didn't run:** they only run when the MySQL data directory is empty. To re-run, remove the volume `~/student-app/mysql-data` (this deletes data).

- **Nginx 502 Bad Gateway:** check `fastcgi_pass` in `default.conf` (`php-fpm:9000`) and ensure php-fpm container is running and connected to `frontend` network.

---

## Cleanup (remove only this project's containers, volumes, networks)

```bash
docker stop nginx php-fpm mysql
docker rm nginx php-fpm mysql
docker network rm frontend backend
docker volume rm $(docker volume ls -q)
sudo rm -rf ~/student-app
```

> Be careful: removing volumes will delete MySQL data.

---

## Recommended improvements (production)

- Use a custom Dockerfile for PHP with required extensions preinstalled.
- Use env files or Docker secrets for DB credentials.
- Protect MySQL from public exposure — keep it inside backend network only.
- Use HTTPS (TLS) on nginx in production.

---

## License
MIT

---

**Done.**
